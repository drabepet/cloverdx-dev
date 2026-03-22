#!/usr/bin/env bash
# run-job.sh — execute a CloverDX job via the REST API and poll until complete
#
# Usage:
#   ./scripts/run-job.sh <sandbox> <file-path-in-sandbox> [key=value ...]
#
# Examples:
#   ./scripts/run-job.sh MySandbox graph/LoadCustomers.grf
#   ./scripts/run-job.sh MySandbox graph/jobflow/LoadAll.jbf
#   ./scripts/run-job.sh MySandbox graph/LoadCustomers.grf hireAge=25 region=EU
#
# Exit codes:
#   0 — FINISHED_OK
#   1 — job finished with error (ABORTED, ERROR, FAILED)
#   2 — usage error or API unreachable

set -euo pipefail

CLOVER_HOST="${CLOVER_HOST:-http://localhost:8083}"
CLOVER_USER="${CLOVER_USER:-clover}"
CLOVER_PASS="${CLOVER_PASS:-clover}"
POLL_INTERVAL="${POLL_INTERVAL:-3}"   # seconds between status polls
MAX_WAIT="${MAX_WAIT:-600}"           # give up after 10 minutes

if [ $# -lt 2 ]; then
  echo "Usage: $0 <sandbox> <file-path-in-sandbox> [key=value ...]" >&2
  echo "  Example: $0 MySandbox graph/LoadCustomers.grf" >&2
  exit 2
fi

SANDBOX="$1"
JOB_FILE="$2"
shift 2

# Build inputParameters JSON from remaining key=value args
INPUT_PARAMS="{}"
if [ $# -gt 0 ]; then
  INPUT_PARAMS=$(python3 -c "
import json, sys
params = {}
for arg in sys.argv[1:]:
    k, _, v = arg.partition('=')
    params[k] = v
print(json.dumps(params))
" "$@")
fi

BODY=$(python3 -c "
import json
body = {
    'sandboxCode': '$SANDBOX',
    'jobFile':     '$JOB_FILE',
    'inputParameters': $INPUT_PARAMS
}
print(json.dumps(body))
")

echo "Submitting: ${SANDBOX}/${JOB_FILE}"
[ "$INPUT_PARAMS" != "{}" ] && echo "Parameters: ${INPUT_PARAMS}"

# POST to /executions
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -u "${CLOVER_USER}:${CLOVER_PASS}" \
  -X POST \
  "${CLOVER_HOST}/clover/api/rest/v1/executions" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$BODY" 2>/dev/null) || {
  echo "ERROR: Could not reach CloverDX server at ${CLOVER_HOST}" >&2
  exit 2
}

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY_RESP=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" != "201" ]; then
  echo "ERROR: execute returned HTTP ${HTTP_CODE}" >&2
  echo "$BODY_RESP" >&2
  exit 2
fi

RUN_ID=$(echo "$BODY_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin)['runId'])" 2>/dev/null)

if [ -z "$RUN_ID" ]; then
  echo "ERROR: could not parse runId from response" >&2
  echo "$BODY_RESP" >&2
  exit 2
fi

echo "Submitted — runId: ${RUN_ID}"
echo "Polling status every ${POLL_INTERVAL}s (max ${MAX_WAIT}s)..."

ELAPSED=0
while [ "$ELAPSED" -lt "$MAX_WAIT" ]; do
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))

  STATUS_RESP=$(curl -s -u "${CLOVER_USER}:${CLOVER_PASS}" \
    -H "Accept: application/json" \
    "${CLOVER_HOST}/clover/api/rest/v1/executions/${RUN_ID}" 2>/dev/null) || continue

  STATUS=$(echo "$STATUS_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" 2>/dev/null)
  DURATION=$(echo "$STATUS_RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('durationString',''))" 2>/dev/null)

  case "$STATUS" in
    FINISHED_OK)
      echo "FINISHED_OK (${DURATION})"
      echo "Tracking: ${CLOVER_HOST}/clover/api/rest/v1/executions/${RUN_ID}/tracking"
      echo "Log:      ${CLOVER_HOST}/clover/api/rest/v1/executions/${RUN_ID}/log"
      exit 0
      ;;
    ABORTED|ERROR|FAILED)
      echo "FAILED: ${STATUS} (${DURATION})"
      echo "Log: ${CLOVER_HOST}/clover/api/rest/v1/executions/${RUN_ID}/log"
      # Print error from log (first ERROR/FATAL line)
      curl -s -u "${CLOVER_USER}:${CLOVER_PASS}" \
        "${CLOVER_HOST}/clover/api/rest/v1/executions/${RUN_ID}/log" 2>/dev/null \
        | grep -m5 -E "(ERROR|FATAL)" || true
      exit 1
      ;;
    RUNNING|WAITING|SCHEDULED)
      printf "  [%ss] %s...\n" "$ELAPSED" "$STATUS"
      ;;
    *)
      printf "  [%ss] status: %s\n" "$ELAPSED" "${STATUS:-unknown}"
      ;;
  esac
done

echo "TIMEOUT: job still running after ${MAX_WAIT}s (runId: ${RUN_ID})" >&2
echo "Check status: ${CLOVER_HOST}/clover/api/rest/v1/executions/${RUN_ID}" >&2
exit 2
