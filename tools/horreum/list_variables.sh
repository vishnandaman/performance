#!/usr/bin/env bash
# List Horreum change-detection variables for a test.
#
# Usage:
#   export REQUESTS_CA_BUNDLE=/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
#   export HORREUM_API_KEY="HUSR_..."   # preferred
#   # or: export HORREUM_TOKEN="..."    # legacy bearer token
#   ./tools/horreum/list_variables.sh [test_id]

set -euo pipefail

HORREUM_URL="${HORREUM_URL:-https://horreum.corp.redhat.com}"
TEST_ID="${1:-${HORREUM_TEST_ID:-391}}"
CA_BUNDLE="${REQUESTS_CA_BUNDLE:-/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem}"

if [[ ! -f "$CA_BUNDLE" ]]; then
  echo "ERROR: CA bundle not found: $CA_BUNDLE" >&2
  echo "Set REQUESTS_CA_BUNDLE to your corporate CA PEM file." >&2
  exit 1
fi

curl_args=(
  -sS
  -f
  --cacert "$CA_BUNDLE"
  -H "Accept: application/json"
)

if [[ -n "${HORREUM_API_KEY:-}" ]]; then
  curl_args+=(-H "X-Horreum-API-Key: ${HORREUM_API_KEY}")
elif [[ -n "${HORREUM_TOKEN:-}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${HORREUM_TOKEN}")
fi

url="${HORREUM_URL%/}/api/alerting/variables?test=${TEST_ID}"

if ! response="$(curl "${curl_args[@]}" "$url")"; then
  echo "ERROR: curl failed for $url" >&2
  echo "Check HORREUM_URL, REQUESTS_CA_BUNDLE, and HORREUM_API_KEY/HORREUM_TOKEN." >&2
  exit 1
fi

python3 -c "
import json, sys

raw = sys.argv[1]
if not raw.strip():
    raise SystemExit('ERROR: empty response from Horreum (auth or TLS issue)')

try:
    variables = json.loads(raw)
except json.JSONDecodeError as exc:
    preview = raw[:200].replace('\n', ' ')
    raise SystemExit(f'ERROR: response is not JSON ({exc}); preview: {preview!r}')

for variable in sorted(variables, key=lambda item: item.get('name', '')):
    print(f\"{variable['id']}:{variable['name']}\")
" "$response"
