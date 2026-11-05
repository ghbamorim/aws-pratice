
import asyncio
import json
import logging
import os
import time
from contextlib import asynccontextmanager
from datetime import datetime
from decimal import Decimal

import boto3
import httpx
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError
from ddtrace import tracer
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, Numeric, String, create_engine, func, select, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s'
)

logger = logging.getLogger('datadog_lab')

engine = create_engine(
    os.environ['DATABASE_URL'],
    pool_pre_ping=True
)

FAULTS_ENABLED = os.getenv('LAB_FAULTS_ENABLED', 'false').lower() == 'true'
LAB_MODE = os.getenv('LAB_MODE', 'local').lower()

LAMBDA_URL = os.getenv(
    'LAMBDA_URL',
    'http://lambda-local:8080/invoke'
)

LAMBDA_FUNCTION_NAME = os.getenv(
    'LAMBDA_FUNCTION_NAME',
    'aws-pratice-lambda'
)

AWS_REGION = os.getenv('AWS_REGION', 'us-east-2')

lambda_client = None

if LAB_MODE == 'aws':
    lambda_client = boto3.client(
        'lambda',
        region_name=AWS_REGION,
        config=Config(
            connect_timeout=2,
            read_timeout=5,
            retries={'max_attempts': 1}
        )
    )

_memory_chunks: list[bytes] = []


class Base(DeclarativeBase):
    pass


class Order(Base):
    __tablename__ = 'orders'

    id: Mapped[int] = mapped_column(primary_key=True)
    customer: Mapped[str] = mapped_column(String(120))
    amount: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    status: Mapped[str] = mapped_column(String(30), default='pending')
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )


class OrderInput(BaseModel):
    customer: str = Field(min_length=1, max_length=120)
    amount: Decimal = Field(
        gt=0,
        max_digits=10,
        decimal_places=2
    )


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    yield


app = FastAPI(
    title='Datadog Lab API',
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv(
        'CORS_ORIGINS',
        'http://localhost:5173'
    ).split(','),
    allow_methods=['*'],
    allow_headers=['*']
)


def serialize(order: Order):
    return {
        'id': order.id,
        'customer': order.customer,
        'amount': str(order.amount),
        'status': order.status
    }


def require_faults():
    if not FAULTS_ENABLED:
        raise HTTPException(
            status_code=404,
            detail='Fault endpoints disabled'
        )


async def invoke_lambda(payload: dict) -> dict:
    if LAB_MODE == 'aws':
        return await asyncio.to_thread(
            invoke_aws_lambda,
            payload
        )

    async with httpx.AsyncClient(timeout=4.0) as client:
        response = await client.post(
            LAMBDA_URL,
            json=payload
        )
        response.raise_for_status()
        return response.json()


def invoke_aws_lambda(payload: dict) -> dict:
    response = lambda_client.invoke(
        FunctionName=LAMBDA_FUNCTION_NAME,
        InvocationType='RequestResponse',
        Payload=json.dumps(payload).encode('utf-8')
    )

    result = json.loads(
        response['Payload'].read().decode('utf-8')
    )

    if response.get('FunctionError'):
        raise RuntimeError(
            f"Lambda execution failed: {result}"
        )

    return result


@app.get('/api/health')
def health():
    with Session(engine) as session:
        session.execute(text('SELECT 1'))

    return {'status': 'ok'}

@app.get('/api/orders')
def list_orders():
    # Span que envolve toda a lógica da rota
    with tracer.trace('orders.list', resource='list_orders') as span, Session(engine) as session:       
            # Passo 1: buscar no banco (SQLAlchemy + Postgres)
            with tracer.trace('orders.query'):
                orders = session.scalars(
                    select(Order)
                    .order_by(Order.id.desc())
                    .limit(100)
                ).all()

            # Guarda quantos pedidos vieram
            span.set_metric('orders.count', len(orders))

            # Passo 2: transformar em dicionários
            with tracer.trace('orders.serialize'):
                result = [serialize(order) for order in orders]

        # Ao sair do "with Session", acontece o close/rollback,
        # ainda dentro de orders.list

    return result

@app.post('/api/orders', status_code=201)
def create_order(payload: OrderInput):
    with Session(engine) as session:
        order = Order(
            customer=payload.customer,
            amount=payload.amount
        )

        session.add(order)
        session.commit()
        session.refresh(order)

        logger.info(
            'order_created order_id=%s',
            order.id
        )

        return serialize(order)


@app.post('/api/orders/{order_id}/process')
async def process_order(order_id: int, fault: str = 'none'):
    if fault not in ('none', 'error', 'timeout'):
        raise HTTPException(400, 'Invalid fault')

    if fault != 'none':
        require_faults()

    with Session(engine) as session:
        order = session.get(Order, order_id)

        if not order:
            raise HTTPException(404, 'Order not found')

        payload = {
            'order_id': order.id,
            'amount': str(order.amount),
            'fault': fault
        }

    try:
        result = await invoke_lambda(payload)

    except (httpx.TimeoutException, TimeoutError):
        logger.exception(
            'lambda_timeout order_id=%s',
            order_id
        )
        raise HTTPException(
            504,
            'Lambda timed out'
        )

    except (
        httpx.HTTPError,
        BotoCoreError,
        ClientError,
        RuntimeError,
        ValueError,
        KeyError
    ):
        logger.exception(
            'lambda_failure order_id=%s',
            order_id
        )
        raise HTTPException(
            502,
            'Lambda processing failed'
        )

    with Session(engine) as session:
        order = session.get(Order, order_id)
        order.status = result['status']
        session.commit()

        return serialize(order)


@app.get('/api/faults/latency')
def fault_latency():
    require_faults()
    time.sleep(2)
    return {'delay_seconds': 2}


@app.get('/api/faults/error')
def fault_error():
    require_faults()

    logger.error('intentional_api_failure')
    raise HTTPException(
        500,
        'Intentional API error'
    )


@app.get('/api/faults/slow-query')
def fault_slow_query():
    require_faults()

    with Session(engine) as session:
        session.execute(text('SELECT pg_sleep(2)'))

    return {'query_delay_seconds': 2}


@app.post('/api/faults/memory')
def fault_memory():
    require_faults()

    # Cap memory allocation at 40 MiB.
    if len(_memory_chunks) >= 8:
        raise HTTPException(
            429,
            'Memory exercise cap reached; reset to release'
        )

    _memory_chunks.append(
        os.urandom(5 * 1024 * 1024)
    )

    return {
        'allocated_mib': len(_memory_chunks) * 5
    }


@app.delete('/api/faults/memory')
def reset_memory():
    require_faults()
    _memory_chunks.clear()

    return {'allocated_mib': 0}
