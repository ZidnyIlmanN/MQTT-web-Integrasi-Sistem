#!/bin/bash

# Test script for MQTT TLS certificates
echo "Testing MQTT TLS connection..."

# Test with mosquitto_pub (if available)
if command -v mosquitto_pub &> /dev/null; then
    echo "Testing MQTT publish with TLS..."
    mosquitto_pub -h localhost -p 8883 --cafile ./certs/ca.crt -t "test/tls" -m "TLS test message" -u testuser -P test123
    echo "TLS test completed"
else
    echo "mosquitto_pub not available - install mosquitto-clients for testing"
fi

# Test certificate expiry
echo "Certificate expiry information:"
echo "CA Certificate expires:"
openssl x509 -in ./certs/ca.crt -noout -enddate

echo "Server Certificate expires:"  
openssl x509 -in ./certs/server.crt -noout -enddate
