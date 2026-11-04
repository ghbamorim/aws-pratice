import base64
import getpass
import hashlib
import json
import subprocess

username = "ghnerique"
password = getpass.getpass("Nova senha: ")

if len(password) < 12:
    raise SystemExit("Use pelo menos 12 caracteres.")

credentials = base64.b64encode(
    f"{username}:{password}".encode()
).decode()

auth_header = f"Basic {credentials}"

digest = hashlib.sha256(
    auth_header.encode()
).hexdigest()

arn = subprocess.check_output(
    ["terraform", "output", "-raw", "auth_kvs_arn"],
    text=True
).strip()

store = json.loads(subprocess.check_output(
    [
        "aws", "cloudfront-keyvaluestore",
        "describe-key-value-store",
        "--kvs-arn", arn
    ],
    text=True
))

subprocess.run(
    [
        "aws", "cloudfront-keyvaluestore", "put-key",
        "--kvs-arn", arn,
        "--key", "basic_auth_hash",
        "--value", digest,
        "--if-match", store["ETag"]
    ],
    check=True
)

print("Senha cadastrada.")
