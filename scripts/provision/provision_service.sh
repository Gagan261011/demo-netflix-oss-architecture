#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:?SERVICE_NAME is required (e.g., user-bff)}"
SERVICE_MODULE="${SERVICE_MODULE:?SERVICE_MODULE is required (e.g., services/user-bff)}"
SERVICE_PORT="${SERVICE_PORT:?SERVICE_PORT is required (e.g., 8081)}"
SPRING_PROFILE="${SPRING_PROFILE:-aws}"

REPO_DIR="${REPO_DIR:-/home/apps/repo}"
APP_DIR="/opt/${SERVICE_NAME}"
ETC_DIR="/etc/${SERVICE_NAME}"
LOG_DIR="/var/log/${SERVICE_NAME}"
JAR_PATH="${APP_DIR}/app.jar"
ENV_FILE="${ETC_DIR}/${SERVICE_NAME}.env"
UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

CONFIG_SERVER_URL="${CONFIG_SERVER_URL:-http://localhost:8888}"
EUREKA_URL="${EUREKA_URL:-http://localhost:8761/eureka}"
CERTS_S3_BUCKET="${CERTS_S3_BUCKET:-}"
EUREKA_DISCOVERY_NAME="${EUREKA_DISCOVERY_NAME:-}"

MIDDLEWARE_HOST="${MIDDLEWARE_HOST:-}"
BACKEND_HOST="${BACKEND_HOST:-}"

MTLS_STOREPASS="${MTLS_STOREPASS:-changeit}"

wait_for_url_simple() {
  local url="$1"
  local max_seconds="${2:-300}"
  echo "Waiting for ${url} ..."
  local start
  start="$(date +%s)"
  while true; do
    if curl -fsS --max-time 5 "${url}" >/dev/null 2>&1; then
      return 0
    fi
    if (( "$(date +%s)" - start > max_seconds )); then
      echo "Timed out waiting for: ${url}" >&2
      return 1
    fi
    sleep 3
  done
}

wait_for_url_mtls() {
  local url="$1"
  local cacert="$2"
  local cert="$3"
  local key="$4"
  echo "Waiting (mTLS) for ${url} ..."
  local start
  start="$(date +%s)"
  while true; do
    if curl -fsS --max-time 5 --cacert "${cacert}" --cert "${cert}" --key "${key}" "${url}" >/dev/null 2>&1; then
      return 0
    fi
    if (( "$(date +%s)" - start > 300 )); then
      echo "Timed out waiting (mTLS) for: ${url}" >&2
      return 1
    fi
    sleep 3
  done
}

install_prereqs() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl jq git unzip awscli openjdk-17-jdk maven rsync
  useradd -m -s /bin/bash apps >/dev/null 2>&1 || true
  mkdir -p "${APP_DIR}" "${ETC_DIR}" "${LOG_DIR}"
  chown -R apps:apps "${APP_DIR}" "${LOG_DIR}" || true
}

clone_or_update_repo() {
  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    echo "Repo not found at ${REPO_DIR}; did user_data clone it?" >&2
    exit 1
  fi
}

build_service() {
  echo "Building ${SERVICE_MODULE}..."
  sudo -u apps bash -lc "cd '${REPO_DIR}' && mvn -pl '${SERVICE_MODULE}' -am clean package -DskipTests"

  local target_dir="${REPO_DIR}/${SERVICE_MODULE}/target"
  local jar
  jar="$(ls -1 "${target_dir}"/*.jar | grep -v 'original' | head -n1)"
  if [[ -z "${jar}" ]]; then
    echo "Build did not produce a jar in ${target_dir}" >&2
    exit 1
  fi
  install -m 0644 "${jar}" "${JAR_PATH}"
}

write_env_file() {
  local certs_dir=""
  if [[ "${SERVICE_NAME}" == "mtls-middleware" || "${SERVICE_NAME}" == "user-bff" ]]; then
    certs_dir="${APP_DIR}/certs"
  fi
  local config_repo_path=""
  if [[ "${SERVICE_NAME}" == "config-server" ]]; then
    config_repo_path="file:/opt/config-repo"
  fi
  cat > "${ENV_FILE}" <<EOF
CONFIG_SERVER_URL=${CONFIG_SERVER_URL}
EUREKA_URL=${EUREKA_URL}
MIDDLEWARE_HOST=${MIDDLEWARE_HOST}
BACKEND_HOST=${BACKEND_HOST}
MTLS_STOREPASS=${MTLS_STOREPASS}
CERTS_DIR=${certs_dir}
CONFIG_REPO_PATH=${config_repo_path}
EOF
  chmod 0644 "${ENV_FILE}"
}

write_application_yml() {
  if [[ "${SERVICE_NAME}" == "config-server" ]]; then
    cat > "${ETC_DIR}/application.yml" <<EOF
spring:
  profiles:
    active: native,${SPRING_PROFILE}
  cloud:
    config:
      server:
        native:
          search-locations: \${CONFIG_REPO_PATH:file:/opt/config-repo}
EOF
    return 0
  fi

  cat > "${ETC_DIR}/application.yml" <<EOF
spring:
  profiles:
    active: ${SPRING_PROFILE}
  config:
    import: "optional:configserver:\${CONFIG_SERVER_URL}"
  cloud:
    config:
      fail-fast: true
EOF
}

sync_config_repo_if_needed() {
  if [[ "${SERVICE_NAME}" != "config-server" ]]; then
    return 0
  fi
  echo "Copying config-repo to /opt/config-repo..."
  mkdir -p /opt/config-repo
  rsync -a --delete "${REPO_DIR}/config-repo/" /opt/config-repo/
  chown -R apps:apps /opt/config-repo || true
}

generate_and_publish_certs_if_needed() {
  if [[ "${SERVICE_NAME}" != "config-server" ]]; then
    return 0
  fi
  echo "Generating mTLS certs via scripts/certs/generate-certs.sh..."
  sudo -u apps bash -lc "cd '${REPO_DIR}' && MTLS_STOREPASS='${MTLS_STOREPASS}' bash scripts/certs/generate-certs.sh '${REPO_DIR}/scripts/certs/out'"

  if [[ -n "${CERTS_S3_BUCKET}" ]]; then
    echo "Uploading certs to s3://${CERTS_S3_BUCKET}/certs ..."
    aws s3 sync "${REPO_DIR}/scripts/certs/out" "s3://${CERTS_S3_BUCKET}/certs" --delete
  else
    echo "CERTS_S3_BUCKET is empty; skipping cert publish." >&2
  fi
}

fetch_certs_if_needed() {
  if [[ "${SERVICE_NAME}" != "mtls-middleware" && "${SERVICE_NAME}" != "user-bff" ]]; then
    return 0
  fi
  if [[ -z "${CERTS_S3_BUCKET}" ]]; then
    echo "CERTS_S3_BUCKET is required for ${SERVICE_NAME} to fetch certs." >&2
    exit 1
  fi
  local tmp="/tmp/mtls-certs"
  rm -rf "${tmp}"
  mkdir -p "${tmp}"
  echo "Downloading certs from s3://${CERTS_S3_BUCKET}/certs ..."
  aws s3 sync "s3://${CERTS_S3_BUCKET}/certs" "${tmp}"

  mkdir -p "${APP_DIR}/certs"
  if [[ "${SERVICE_NAME}" == "mtls-middleware" ]]; then
    install -m 0644 "${tmp}/middleware-server-keystore.p12" "${APP_DIR}/certs/middleware-server-keystore.p12"
    install -m 0644 "${tmp}/middleware-server-truststore.p12" "${APP_DIR}/certs/middleware-server-truststore.p12"
    install -m 0644 "${tmp}/root-ca.crt" "${APP_DIR}/certs/root-ca.crt"
    # for health checks from other services
    install -m 0600 "${tmp}/user-bff-client.key" "${APP_DIR}/certs/user-bff-client.key"
    install -m 0644 "${tmp}/user-bff-client.crt" "${APP_DIR}/certs/user-bff-client.crt"
  fi
  if [[ "${SERVICE_NAME}" == "user-bff" ]]; then
    install -m 0644 "${tmp}/user-bff-client-keystore.p12" "${APP_DIR}/certs/user-bff-client-keystore.p12"
    install -m 0644 "${tmp}/user-bff-client-truststore.p12" "${APP_DIR}/certs/user-bff-client-truststore.p12"
    install -m 0644 "${tmp}/root-ca.crt" "${APP_DIR}/certs/root-ca.crt"
    install -m 0600 "${tmp}/user-bff-client.key" "${APP_DIR}/certs/user-bff-client.key"
    install -m 0644 "${tmp}/user-bff-client.crt" "${APP_DIR}/certs/user-bff-client.crt"
  fi

  chown -R apps:apps "${APP_DIR}/certs" || true
}

install_systemd_unit() {
  cat > "${UNIT_FILE}" <<EOF
[Unit]
Description=${SERVICE_NAME}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=apps
WorkingDirectory=${APP_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=/usr/bin/java -jar ${JAR_PATH} --spring.config.additional-location=file:${ETC_DIR}/
Restart=on-failure
RestartSec=3
StandardOutput=append:${LOG_DIR}/app.log
StandardError=append:${LOG_DIR}/app.log

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "${SERVICE_NAME}.service"
}

discover_eureka_url_by_tag() {
  local name_tag="$1"
  local start
  start="$(date +%s)"
  while true; do
    local ip
    ip="$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=${name_tag}" "Name=instance-state-name,Values=running" \
      --query "Reservations[0].Instances[0].PrivateIpAddress" \
      --output text 2>/dev/null || true)"
    if [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "http://${ip}:8761/eureka"
      return 0
    fi
    if (( "$(date +%s)" - start > 600 )); then
      echo "Timed out discovering Eureka by tag Name=${name_tag}" >&2
      return 1
    fi
    sleep 5
  done
}

replace_env_line() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}=" "${ENV_FILE}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${ENV_FILE}"
  else
    echo "${key}=${value}" >> "${ENV_FILE}"
  fi
}

wait_for_dependencies() {
  local urls="${WAIT_FOR_URLS:-}"
  if [[ -z "${urls}" ]]; then
    :
  else
    for url in ${urls}; do
      wait_for_url_simple "${url}"
    done
  fi

  local mtls_urls="${WAIT_FOR_MTLS_URLS:-}"
  if [[ -z "${mtls_urls}" ]]; then
    return 0
  fi

  local cacert="${APP_DIR}/certs/root-ca.crt"
  local cert="${APP_DIR}/certs/user-bff-client.crt"
  local key="${APP_DIR}/certs/user-bff-client.key"

  for url in ${mtls_urls}; do
    wait_for_url_mtls "${url}" "${cacert}" "${cert}" "${key}"
  done
}

start_and_wait_healthy() {
  systemctl restart "${SERVICE_NAME}.service"

  local health_url="${HEALTH_URL:-http://127.0.0.1:${SERVICE_PORT}/actuator/health}"
  if [[ "${SERVICE_NAME}" == "mtls-middleware" ]]; then
    health_url="${HEALTH_URL:-https://127.0.0.1:8443/actuator/health}"
    wait_for_url_mtls "${health_url}" "${APP_DIR}/certs/root-ca.crt" "${APP_DIR}/certs/user-bff-client.crt" "${APP_DIR}/certs/user-bff-client.key"
  else
    wait_for_url_simple "${health_url}"
  fi
}

main() {
  install_prereqs
  clone_or_update_repo

  sync_config_repo_if_needed
  generate_and_publish_certs_if_needed
  fetch_certs_if_needed

  write_env_file
  write_application_yml
  build_service

  install_systemd_unit
  wait_for_dependencies
  start_and_wait_healthy

  if [[ "${SERVICE_NAME}" == "config-server" && -n "${EUREKA_DISCOVERY_NAME}" ]]; then
    echo "Discovering Eureka URL for config-server via EC2 tag Name=${EUREKA_DISCOVERY_NAME}..."
    local discovered
    discovered="$(discover_eureka_url_by_tag "${EUREKA_DISCOVERY_NAME}")"
    echo "Discovered Eureka URL: ${discovered}"
    replace_env_line "EUREKA_URL" "${discovered}"
    systemctl restart "${SERVICE_NAME}.service"
    wait_for_url_simple "http://127.0.0.1:${SERVICE_PORT}/actuator/health"
  fi

  echo "Provisioned ${SERVICE_NAME}"
}

main "$@"
