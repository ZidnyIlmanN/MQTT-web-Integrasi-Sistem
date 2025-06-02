# Certificates Directory

This directory should contain the necessary TLS/SSL certificate files for the Mosquitto MQTT broker.

Required files:
- ca.crt : CA certificate
- server.crt : Server certificate
- server.key : Server private key

If you do not have these certificates, you can generate self-signed certificates for testing purposes using OpenSSL.

Example commands to generate self-signed certificates:

```bash
# Generate CA private key and certificate
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 365 -key ca.key -out ca.crt -subj "/CN=MyCA"

# Generate server private key and CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -subj "/CN=localhost"

# Sign server certificate with CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
```

Place the generated `ca.crt`, `server.crt`, and `server.key` files into this `certs` directory.

After placing the certificates, restart the Docker Compose services.
