import cf from "cloudfront";
import crypto from "crypto";

const kvs = cf.kvs();

async function handler(event) {
  const request = event.request;
  const authorization = request.headers.authorization;

  if (authorization && authorization.value) {
    const receivedHash = crypto
      .createHash("sha256")
      .update(authorization.value)
      .digest("hex");

    try {
      const expectedHash = await kvs.get("basic_auth_hash");

      if (receivedHash === expectedHash) {
        // Não encaminhar as credenciais para a EC2.
        delete request.headers.authorization;
        return request;
      }
    } catch (error) {
      console.log("Authentication configuration unavailable");
    }
  }

  return {
    statusCode: 401,
    statusDescription: "Unauthorized",
    headers: {
      "www-authenticate": {
        value: 'Basic realm="AWS Practice Lab"',
      },
      "cache-control": {
        value: "no-store",
      },
    },
  };
}
