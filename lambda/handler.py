import logging
import time

logger = logging.getLogger(__name__)

def handler(event, context):
    fault = event.get('fault', 'none')
    order_id = event['order_id']
    logger.warning('lambda_processing order_id=%s fault=%s', order_id, fault)
    if fault == 'error':
        raise RuntimeError('Intentional Lambda failure')
    if fault == 'timeout':
        time.sleep(6)
    return {'order_id': order_id, 'status': 'processed'}
