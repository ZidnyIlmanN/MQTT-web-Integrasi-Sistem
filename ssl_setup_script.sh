#!/bin/bash

# =================================================================
# SSL/TLS Certificate Generation Script
# MQTT IoT Dashboard - Security Setup
# =================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CERT_DIR="./certs"
CONFIG_DIR="./mosquitto/config"
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORGANIZATION="MQTT IoT Dashboard"
ORGANIZATIONAL_UNIT="IT Department"
COMMON_NAME="mqtt.localhost"
EMAIL="admin@mqtt.localhost"

# Certificate validity (days)
CERT_VALIDITY=365

echo -e "${BLUE}==================================================================${NC}"
echo -e "${BLUE}MQTT IoT Dashboard - SSL/TLS Certificate Setup${NC}"
echo -e "${BLUE}==================================================================${NC}"

# Create directories
echo -e "${YELLOW}Creating certificate directories...${NC}"
mkdir -p ${CERT_DIR}
mkdir -p ${CONFIG_DIR}
mkdir -p ./mosquitto/data
mkdir -p ./mosquitto/logs

# Generate CA private key
echo -e "${YELLOW}Generating CA private key...${NC}"
openssl genrsa -out ${CERT_DIR}/ca.key 4096

# Generate CA certificate
echo -e "${YELLOW}Generating CA certificate...${NC}"
openssl req -new -x509 -days ${CERT_VALIDITY} -key ${CERT_DIR}/ca.key -out ${CERT_DIR}/ca.crt -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=MQTT-CA/emailAddress=${EMAIL}"

# Generate server private key
echo -e "${YELLOW}Generating server private key...${NC}"
openssl genrsa -out ${CERT_DIR}/server.key 4096

# Generate server certificate signing request
echo -e "${YELLOW}Generating server certificate signing request...${NC}"
openssl req -new -key ${CERT_DIR}/server.key -out ${CERT_DIR}/server.csr -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${COMMON_NAME}/emailAddress=${EMAIL}"

# Create extensions file for server certificate
echo -e "${YELLOW}Creating server certificate extensions...${NC}"
cat > ${CERT_DIR}/server.ext << EOF
[v3_req]
basicConstraints = CA:FALSE
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${COMMON_NAME}
DNS.2 = localhost
DNS.3 = mosquitto
DNS.4 = mqtt-broker
IP.1 = 127.0.0.1
IP.2 = 192.168.1.100
IP.3 = 172.20.0.2
EOF

# Generate server certificate
echo -e "${YELLOW}Generating server certificate...${NC}"
openssl x509 -req -in ${CERT_DIR}/server.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/server.crt -days ${CERT_VALIDITY} -extensions v3_req -extfile ${CERT_DIR}/server.ext

# Generate client private key (for mutual TLS if needed)
echo -e "${YELLOW}Generating client private key...${NC}"
openssl genrsa -out ${CERT_DIR}/client.key 4096

# Generate client certificate signing request
echo -e "${YELLOW}Generating client certificate signing request...${NC}"
openssl req -new -key ${CERT_DIR}/client.key -out ${CERT_DIR}/client.csr -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=mqtt-client/emailAddress=${EMAIL}"

# Generate client certificate
echo -e "${YELLOW}Generating client certificate...${NC}"
openssl x509 -req -in ${CERT_DIR}/client.csr -CA ${CERT_DIR}/ca.crt -CAkey ${CERT_DIR}/ca.key -CAcreateserial -out ${CERT_DIR}/client.crt -days ${CERT_VALIDITY}

# Set proper permissions
echo -e "${YELLOW}Setting certificate permissions...${NC}"
chmod 600 ${CERT_DIR}/*.key
chmod 644 ${CERT_DIR}/*.crt
chmod 644 ${CERT_DIR}/*.csr

# Create MQTT password file
echo -e "${YELLOW}Creating MQTT password file...${NC}"
cat > ${CONFIG_DIR}/passwd << EOF
# MQTT User Passwords
# Format: username:password_hash
# Generate hash with: mosquitto_passwd -c passwd username
EOF

# Create users with mosquitto_passwd (if available)
if command -v mosquitto_passwd &> /dev/null; then
    echo -e "${YELLOW}Creating MQTT users...${NC}"
    
    # Create password file with users
    mosquitto_passwd -c ${CONFIG_DIR}/passwd admin
    mosquitto_passwd ${CONFIG_DIR}/passwd dashboard  
    mosquitto_passwd ${CONFIG_DIR}/passwd device001
    mosquitto_passwd ${CONFIG_DIR}/passwd device002
    mosquitto_passwd ${CONFIG_DIR}/passwd device003
    mosquitto_passwd ${CONFIG_DIR}/passwd monitor
    mosquitto_passwd ${CONFIG_DIR}/passwd guest
    mosquitto_passwd ${CONFIG_DIR}/passwd testuser
    mosquitto_passwd ${CONFIG_DIR}/passwd developer
    
    echo -e "${GREEN}MQTT users created successfully!${NC}"
    echo -e "${YELLOW}Default users: admin, dashboard, device001-003, monitor, guest, testuser, developer${NC}"
else
    echo -e "${RED}mosquitto_passwd not found. Please install mosquitto-clients package.${NC}"
    echo -e "${YELLOW}Manual password creation required.${NC}"
    
    # Create default passwords manually (for demonstration)
    cat > ${CONFIG_DIR}/passwd << EOF
admin:\$7\$101\$GZNfkKTGLqhKWi9k\$3Jml8VZRl5EhFDjPQUE1x3xJ7rqGpJLzFtNyYTGxcE8=
dashboard:\$7\$101\$9GJPpVGhFgDZqF3m\$8vNxz2QF5YrT4pR7wH9jMzL1cK6sB3dE0aW8uI5tY7X=
testuser:\$7\$101\$5RhKqWmNxLzJfG8v\$2pT4w6H8vR3nY5jM7zL9qE1cF0xB4sD8aU2iO6gK3tV=
EOF
fi

# Create combined certificate file for some applications
echo -e "${YELLOW}Creating combined certificate file...${NC}"
cat ${CERT_DIR}/server.crt ${CERT_DIR}/ca.crt > ${CERT_DIR}/server-combined.crt

# Verify certificates
echo -e "${YELLOW}Verifying certificates...${NC}"
echo -e "${BLUE}CA Certificate:${NC}"
openssl x509 -in ${CERT_DIR}/ca.crt -text -noout | grep -E "(Subject|Validity|DNS|IP)"

echo -e "${BLUE}Server Certificate:${NC}"
openssl x509 -in ${CERT_DIR}/server.crt -text -noout | grep -E "(Subject|Validity|DNS|IP)"

# Verify server certificate against CA
echo -e "${YELLOW}Verifying server certificate against CA...${NC}"
if openssl verify -CAfile ${CERT_DIR}/ca.crt ${CERT_DIR}/server.crt; then
    echo -e "${GREEN}Server certificate verification: PASSED${NC}"
else
    echo -e "${RED}Server certificate verification: FAILED${NC}"
    exit 1
fi

# Create certificate info file
echo -e "${YELLOW}Creating certificate information file...${NC}"
cat > ${CERT_DIR}/cert_info.txt << EOF
=================================================================
MQTT IoT Dashboard - Certificate Information
=================================================================

Generated: $(date)
Validity: ${CERT_VALIDITY} days
Common Name: ${COMMON_NAME}

Files Created:
- ca.key          : CA private key
- ca.crt          : CA certificate  
- server.key      : Server private key
- server.crt      : Server certificate
- server.csr      : Server certificate signing request
- client.key      : Client private key
- client.crt      : Client certificate
- server-combined.crt : Combined server + CA certificate

Certificate Details:
- Country: ${COUNTRY}
- State: ${STATE}
- City: ${CITY}
- Organization: ${ORGANIZATION}
- Organizational Unit: ${ORGANIZATIONAL_UNIT}
- Email: ${EMAIL}

Subject Alternative Names:
- DNS: ${COMMON_NAME}
- DNS: localhost
- DNS: mosquitto
- DNS: mqtt-broker
- IP: 127.0.0.1
- IP: 192.168.1.100
- IP: 172.20.0.2

Usage:
1. Place certificates in mosquitto config directory
2. Update mosquitto.conf to use these certificates
3. Configure clients to use ca.crt for verification
4. For mutual TLS, use client.crt and client.key

Security Notes:
- Keep private keys (.key files) secure
- Distribute only the CA certificate to clients
- Regenerate certificates before expiry
- Use proper file permissions (600 for .key, 644 for .crt)
=================================================================
EOF

# Create quick test script
echo -e "${YELLOW}Creating certificate test script...${NC}"
cat > ${CERT_DIR}/test_certs.sh << 'EOF'
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
EOF

chmod +x ${CERT_DIR}/test_certs.sh

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}SSL/TLS Certificate Setup Completed Successfully!${NC}"
echo -e "${GREEN}==================================================================${NC}"
echo -e "${YELLOW}Certificate files created in: ${CERT_DIR}${NC}"
echo -e "${YELLOW}Password file created in: ${CONFIG_DIR}/passwd${NC}"
echo -e "${YELLOW}Certificate info saved in: ${CERT_DIR}/cert_info.txt${NC}"
echo -e "${YELLOW}Test script available: ${CERT_DIR}/test_certs.sh${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Copy mosquitto.conf to ${CONFIG_DIR}/"
echo -e "2. Copy acl file to ${CONFIG_DIR}/"
echo -e "3. Start MQTT broker: docker-compose up -d mosquitto"
echo -e "4. Test TLS connection: ./certs/test_certs.sh"
echo -e "5. Access dashboard: http://localhost:3000"
echo ""
echo -e "${GREEN}Setup completed successfully!${NC}"