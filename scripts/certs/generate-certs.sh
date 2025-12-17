#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/out}"
PASS="${MTLS_STOREPASS:-changeit}"

mkdir -p "${OUT_DIR}"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

require openssl
require keytool

ROOT_KEY="${OUT_DIR}/root-ca.key"
ROOT_CRT="${OUT_DIR}/root-ca.crt"

create_root_ca() {
  openssl genrsa -out "${ROOT_KEY}" 4096
  openssl req -x509 -new -nodes -key "${ROOT_KEY}" \
    -sha256 -days 3650 \
    -subj "/C=US/ST=Demo/L=Demo/O=NetflixOSS Demo/OU=Platform/CN=demo-root-ca" \
    -out "${ROOT_CRT}"
}

create_signed_cert() {
  local name="$1"
  local cn="$2"

  local key="${OUT_DIR}/${name}.key"
  local csr="${OUT_DIR}/${name}.csr"
  local crt="${OUT_DIR}/${name}.crt"
  local ext="${OUT_DIR}/${name}.ext"

  cat > "${ext}" <<EOF
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth,clientAuth
subjectAltName=DNS:${cn},DNS:localhost,IP:127.0.0.1
EOF

  openssl genrsa -out "${key}" 2048
  openssl req -new -key "${key}" \
    -subj "/C=US/ST=Demo/L=Demo/O=NetflixOSS Demo/OU=Platform/CN=${cn}" \
    -out "${csr}"

  openssl x509 -req -in "${csr}" -CA "${ROOT_CRT}" -CAkey "${ROOT_KEY}" \
    -CAcreateserial -out "${crt}" -days 825 -sha256 -extfile "${ext}"
}

create_pkcs12_keystore() {
  local base="$1"
  local alias="$2"
  local out_name="$3"
  local key="${OUT_DIR}/${base}.key"
  local crt="${OUT_DIR}/${base}.crt"
  local p12="${OUT_DIR}/${out_name}.p12"

  openssl pkcs12 -export \
    -name "${alias}" \
    -inkey "${key}" \
    -in "${crt}" \
    -certfile "${ROOT_CRT}" \
    -out "${p12}" \
    -passout "pass:${PASS}"
}

create_pkcs12_truststore() {
  local name="$1"
  local p12="${OUT_DIR}/${name}.p12"

  rm -f "${p12}"
  keytool -importcert -noprompt \
    -alias root-ca \
    -file "${ROOT_CRT}" \
    -keystore "${p12}" \
    -storetype PKCS12 \
    -storepass "${PASS}"
}

echo "Generating root CA..."
create_root_ca

echo "Generating middleware server cert..."
create_signed_cert "middleware-server" "mtls-middleware"
create_pkcs12_keystore "middleware-server" "middleware-server" "middleware-server-keystore"

echo "Generating user-bff client cert..."
create_signed_cert "user-bff-client" "user-bff"
create_pkcs12_keystore "user-bff-client" "user-bff-client" "user-bff-client-keystore"

echo "Generating truststores..."
create_pkcs12_truststore "middleware-server-truststore"
create_pkcs12_truststore "user-bff-client-truststore"

echo "Done. Output: ${OUT_DIR}"
