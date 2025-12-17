#!/usr/bin/env bash
set -euo pipefail

GATEWAY_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gateway-url)
      GATEWAY_URL="$2"
      shift 2
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "${GATEWAY_URL}" ]]; then
  echo "Usage: $0 --gateway-url http://<gateway-ip>:8080" >&2
  exit 2
fi

PY="python3"
command -v python3 >/dev/null 2>&1 || PY="python"

mkdir -p "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../reports" && pwd)"

${PY} "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run_sanity.py" \
  --gateway-url "${GATEWAY_URL}" \
  --out-json "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../reports" && pwd)/sanity-report.json" \
  --out-html "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../reports" && pwd)/sanity-report.html"

