#!/usr/bin/env bash
# checkconfig.sh — validate a CloverDX job file via the checkConfig API
#
# Usage:
#   ./scripts/checkconfig.sh <sandbox> <file-path-in-sandbox>
#
# Examples:
#   ./scripts/checkconfig.sh MySandbox graph/LoadCustomers.grf
#   ./scripts/checkconfig.sh MySandbox graph/subgraph/OrdersReader.sgrf
#   ./scripts/checkconfig.sh MySandbox graph/jobflow/LoadAll.jbf
#
# Exit codes:
#   0 — valid (no issues)
#   1 — validation issues found (issues printed to stdout as JSON)
#   2 — usage error or API unreachable

set -euo pipefail

CLOVER_HOST="${CLOVER_HOST:-http://localhost:8083}"
CLOVER_USER="${CLOVER_USER:-clover}"
CLOVER_PASS="${CLOVER_PASS:-clover}"

if [ $# -ne 2 ]; then
  echo "Usage: $0 <sandbox> <file-path-in-sandbox>" >&2
  echo "  Example: $0 MySandbox graph/LoadCustomers.grf" >&2
  exit 2
fi

SANDBOX="$1"
FILE_URL="$2"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -u "${CLOVER_USER}:${CLOVER_PASS}" \
  -G "${CLOVER_HOST}/clover/data-service/checkConfig" \
  --data-urlencode "SANDBOX=${SANDBOX}" \
  --data-urlencode "FILE_URL=${FILE_URL}" \
  -H "accept: application/json" 2>/dev/null) || {
  echo "ERROR: Could not reach CloverDX server at ${CLOVER_HOST}" >&2
  exit 2
}

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: checkConfig returned HTTP ${HTTP_CODE}" >&2
  echo "$BODY" >&2
  exit 2
fi

# Empty array = valid
if [ "$BODY" = "[]" ] || [ -z "$BODY" ]; then
  echo "OK: ${SANDBOX}/${FILE_URL} is valid"
  exit 0
fi

# Issues found — print them and exit 1
echo "ISSUES in ${SANDBOX}/${FILE_URL}:"
echo "$BODY" | python3 -c "
import json, sys
issues = json.load(sys.stdin)
for i, issue in enumerate(issues, 1):
    severity = issue.get('severity', 'ERROR')
    message  = issue.get('message', str(issue))
    component = issue.get('componentId', '')
    loc = f' [{component}]' if component else ''
    print(f'  {i}. [{severity}]{loc} {message}')
" 2>/dev/null || echo "$BODY"

exit 1
