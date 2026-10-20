# Fullstack Lab - API

FastAPI + SQLAlchemy + Alembic + PostgreSQL + S3.

Na raiz do repositorio:

```bash
docker compose up -d --build
docker compose exec api alembic upgrade head
```

Abra http://localhost:8000/docs para testar os endpoints.

Exemplo:

```bash
curl -X POST http://localhost:8000/api/items -H 'Content-Type: application/json' -d '{"name":"Meu item"}'
curl http://localhost:8000/api/items/1
```

S3 requer S3_BUCKET e credenciais AWS por role no ECS; os endpoints de anexos retornam 503 enquanto o bucket nao estiver configurado.

Nao use a senha de desenvolvimento do Compose em producao.
