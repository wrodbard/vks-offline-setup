#!/bin/bash
set -o pipefail
source ./config/env.config

mkdir -p "${REGISTRY_CERT_FOLDER}"
sudo apt install -y ca-certificates
cakeyfile=${REGISTRY_CERT_FOLDER}/$(hostname)-ca.key
cacrtfile=${REGISTRY_CERT_FOLDER}/$(hostname)-ca.crt

if [ ! -f "${cakeyfile}" ] || [ ! -f "${cacrtfile}" ]; then
  	echo "CA cert ${cacrtfile} and key ${cakeyfile} do not exist."
	echo "Generating them before generating the server certificate..."

	# Generate a CA Cert Private Key"
	openssl genrsa -out "${cakeyfile}" 4096

	# Generate a CA Cert Certificate"
	openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=US/ST=VA/L=Ashburn/O=SE/OU=Personal/CN=$(hostname)" -key "${cakeyfile}" -out "${cacrtfile}"

	echo sudo cp -p "${cacrtfile}" /usr/local/share/ca-certificates/$(hostname)-ca.crt
	echo 
	echo
	echo "For photon copy the ${cacrtfile} cert to /etc/ssl/certs/"
	echo "           Execute rehash_ca_certificates.sh to update the CA bundle"
	echo
	echo "For Ubuntu CA file ${cacrtfile} copied to /usr/local/share/ca-certificates/$(hostname)-ca.crt."
	echo "           Execute sudo update-ca-certificates after this script has completed execution"
	echo
	echo
fi

# Generate a Server Certificate Private Key"
openssl genrsa -out "${REGISTRY_CERT_FOLDER}"/"${BOOTSTRAP_REGISTRY}".key 4096
openssl genrsa -out "${REGISTRY_CERT_FOLDER}"/"${PLATFORM_REGISTRY}".key 4096

# Generate a Server Certificate Signing Request"
openssl req -sha512 -new -subj "/C=US/ST=CA/L=PaloAlto/O=Engineering/OU=Harbor/CN=${BOOTSTRAP_REGISTRY}" -key "${REGISTRY_CERT_FOLDER}"/"${BOOTSTRAP_REGISTRY}".key -out "${REGISTRY_CERT_FOLDER}"/"${BOOTSTRAP_REGISTRY}".csr
openssl req -sha512 -new -subj "/C=US/ST=CA/L=PaloAlto/O=Engineering/OU=Harbor/CN=${PLATFORM_REGISTRY}"  -key "${REGISTRY_CERT_FOLDER}"/"${PLATFORM_REGISTRY}".key  -out "${REGISTRY_CERT_FOLDER}"/"${PLATFORM_REGISTRY}".csr

# Generate a x509 v3 extension file"
cat > "${REGISTRY_CERT_FOLDER}"/v3_1.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=${BOOTSTRAP_REGISTRY}
DNS.2=*.${BOOTSTRAP_REGISTRY}
IP.1=${BOOTSTRAP_REGISTRY_IP}
EOF

cat > "${REGISTRY_CERT_FOLDER}"/v3_2.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=${PLATFORM_REGISTRY}
DNS.2=*.${PLATFORM_REGISTRY}
EOF

# Use the x509 v3 extension file to generate a cert for the Harbor hosts."
openssl x509 -req -sha512 -days 365 -extfile "${REGISTRY_CERT_FOLDER}"/v3_1.ext -CA "${cacrtfile}" -CAkey "${cakeyfile}" -CAcreateserial -in "${REGISTRY_CERT_FOLDER}"/"${BOOTSTRAP_REGISTRY}".csr -out "${REGISTRY_CERT_FOLDER}"/"${BOOTSTRAP_REGISTRY}".crt
openssl x509 -req -sha512 -days 365 -extfile "${REGISTRY_CERT_FOLDER}"/v3_2.ext -CA "${cacrtfile}" -CAkey "${cakeyfile}" -CAcreateserial -in "${REGISTRY_CERT_FOLDER}"/"${PLATFORM_REGISTRY}".csr  -out "${REGISTRY_CERT_FOLDER}"/"${PLATFORM_REGISTRY}".crt
