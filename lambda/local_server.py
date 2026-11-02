from fastapi import FastAPI
from handler import handler

app = FastAPI()

@app.post('/invoke')
def invoke(event: dict):
    return handler(event, None)
