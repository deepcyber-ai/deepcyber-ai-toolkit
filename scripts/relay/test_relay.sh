#!/bin/bash
set -e

# ── Configuration ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MOCK_PORT="${MOCK_PORT:-19876}"
RELAY_PORT="${RELAY_PORT:-19877}"

TEST_SECRET="test-secret-for-integration"
TEST_JWT="original-test-jwt-token"
SWAPPED_JWT="swapped-test-jwt-token"
TEST_RATE_LIMIT=5
TEST_ALLOWED_PATHS="/api,/v1"
TEST_BLOCKED_PATHS="/admin"

TMPDIR_AUDIT="$(mktemp -d)"

# Check ports are free before starting
for PORT in $MOCK_PORT $RELAY_PORT; do
    if lsof -ti :"$PORT" > /dev/null 2>&1; then
        echo "ERROR: Port $PORT is already in use. Kill the process or set MOCK_PORT/RELAY_PORT."
        exit 1
    fi
done

PASS=0
FAIL=0
TOTAL=0

# ── Cleanup ───────────────────────────────────────────────────────────────

cleanup() {
    echo ""
    echo "Cleaning up..."
    [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null || true
    [ -n "$RELAY_PID" ] && kill "$RELAY_PID" 2>/dev/null || true
    wait "$MOCK_PID" 2>/dev/null || true
    wait "$RELAY_PID" 2>/dev/null || true
    rm -rf "$TMPDIR_AUDIT"
    echo "Done."
}
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────

assert() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))
    if [ "$actual" = "$expected" ]; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected=$expected, got=$actual)"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local name="$1"
    local needle="$2"
    local haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $name (expected to contain '$needle')"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local name="$1"
    local needle="$2"
    local haystack="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$haystack" | grep -q "$needle"; then
        echo "  FAIL: $name (should not contain '$needle')"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $name"
        PASS=$((PASS + 1))
    fi
}

# ── Start mock echo target ───────────────────────────────────────────────

echo "=== DeepCyber Relay Proxy Integration Tests ==="
echo ""
echo "Starting mock target on port $MOCK_PORT..."

python3 -c "
import json
from http.server import HTTPServer, BaseHTTPRequestHandler

class Echo(BaseHTTPRequestHandler):
    def do_ANY(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''
        resp = json.dumps({
            'method': self.command,
            'path': self.path,
            'headers': dict(self.headers),
            'body': body.decode('utf-8', errors='replace')
        })
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(resp.encode())

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_OPTIONS = do_HEAD = do_ANY

    def log_message(self, fmt, *args):
        pass

HTTPServer(('127.0.0.1', $MOCK_PORT), Echo).serve_forever()
" &
MOCK_PID=$!

# ── Start relay proxy ────────────────────────────────────────────────────

echo "Starting relay proxy on port $RELAY_PORT..."

TARGET_API="http://127.0.0.1:$MOCK_PORT" \
RELAY_PORT="$RELAY_PORT" \
RELAY_SECRET="$TEST_SECRET" \
JWT_TOKEN="$TEST_JWT" \
ALLOWED_PATHS="$TEST_ALLOWED_PATHS" \
BLOCKED_PATHS="$TEST_BLOCKED_PATHS" \
RATE_LIMIT="$TEST_RATE_LIMIT" \
LOG_DIR="$TMPDIR_AUDIT" \
python3 "$SCRIPT_DIR/relay_proxy.py" > /dev/null 2>&1 &
RELAY_PID=$!

# ── Wait for readiness ───────────────────────────────────────────────────

echo "Waiting for services..."

for i in $(seq 1 25); do
    if curl -s -o /dev/null "http://127.0.0.1:$RELAY_PORT/__relay/health" 2>/dev/null; then
        break
    fi
    sleep 0.2
done

if ! kill -0 "$MOCK_PID" 2>/dev/null; then
    echo "ERROR: Mock target failed to start"
    exit 1
fi
if ! kill -0 "$RELAY_PID" 2>/dev/null; then
    echo "ERROR: Relay proxy failed to start"
    exit 1
fi

echo "Both services ready."

# Allow test failures without aborting the script
set +e

RELAY="http://127.0.0.1:$RELAY_PORT"

# ── Management Endpoints ─────────────────────────────────────────────────

echo ""
echo "--- Management Endpoints ---"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$RELAY/__relay/health")
assert "Health endpoint returns 200 without auth" "200" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$RELAY/__relay/stats")
assert "Stats endpoint returns 401 without auth" "401" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Relay-Secret: $TEST_SECRET" \
    "$RELAY/__relay/stats")
assert "Stats endpoint returns 200 with auth" "200" "$STATUS"

# ── Authentication ────────────────────────────────────────────────────────

echo ""
echo "--- Authentication ---"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$RELAY/api/test")
assert "Request without secret returns 401" "401" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Relay-Secret: wrong-secret" \
    "$RELAY/api/test")
assert "Request with wrong secret returns 401" "401" "$STATUS"

# ── Path Filtering ────────────────────────────────────────────────────────

echo ""
echo "--- Path Filtering ---"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Relay-Secret: $TEST_SECRET" \
    "$RELAY/api/test")
assert "Request to allowed path succeeds" "200" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Relay-Secret: $TEST_SECRET" \
    "$RELAY/admin/users")
assert "Request to blocked path returns 403" "403" "$STATUS"

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "X-Relay-Secret: $TEST_SECRET" \
    "$RELAY/other/endpoint")
assert "Request to unlisted path is denied" "403" "$STATUS"

# ── Header Handling ───────────────────────────────────────────────────────

# Clear rate limit window from path filtering tests
sleep 1

echo ""
echo "--- Header Handling ---"

BODY=$(curl -s -H "X-Relay-Secret: $TEST_SECRET" "$RELAY/api/test")
assert_contains "JWT is injected into forwarded request" "Bearer $TEST_JWT" "$BODY"
assert_not_contains "X-Relay-Secret is not forwarded to target" "X-Relay-Secret" "$BODY"

# ── Request Forwarding ────────────────────────────────────────────────────

echo ""
echo "--- Request Forwarding ---"

BODY=$(curl -s -H "X-Relay-Secret: $TEST_SECRET" \
    "$RELAY/api/search?q=hello&page=2")
assert_contains "Query string is preserved" "q=hello&page=2" "$BODY"

BODY=$(curl -s -X POST \
    -H "X-Relay-Secret: $TEST_SECRET" \
    -H "Content-Type: application/json" \
    -d '{"prompt":"test input"}' \
    "$RELAY/api/completions")
assert_contains "POST body is forwarded correctly" "test input" "$BODY"

# ── Rate Limiting ─────────────────────────────────────────────────────────

echo ""
echo "--- Rate Limiting ---"

# Clear the sliding window from earlier requests
sleep 1

RATE_LIMITED="no"
for i in $(seq 1 $((TEST_RATE_LIMIT + 1))); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "X-Relay-Secret: $TEST_SECRET" \
        "$RELAY/api/test")
    if [ "$STATUS" = "429" ]; then
        RATE_LIMITED="yes"
        break
    fi
done
assert "Rate limiting kicks in after $TEST_RATE_LIMIT requests" "yes" "$RATE_LIMITED"

# ── JWT Hot-Swap ──────────────────────────────────────────────────────────

echo ""
echo "--- JWT Hot-Swap ---"

# Clear the rate limit window
sleep 1

STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    -H "X-Relay-Secret: $TEST_SECRET" \
    -H "Content-Type: application/json" \
    -d "{\"token\": \"$SWAPPED_JWT\"}" \
    "$RELAY/__relay/update-jwt")
assert "JWT update endpoint returns 200" "200" "$STATUS"

BODY=$(curl -s -H "X-Relay-Secret: $TEST_SECRET" "$RELAY/api/test")
assert_contains "New JWT is used after hot-swap" "Bearer $SWAPPED_JWT" "$BODY"

# ── Audit Trail ───────────────────────────────────────────────────────────

echo ""
echo "--- Audit Trail ---"

AUDIT_FILE=$(ls "$TMPDIR_AUDIT"/relay_audit_*.jsonl 2>/dev/null | head -1)

TOTAL=$((TOTAL + 1))
if [ -n "$AUDIT_FILE" ] && [ -s "$AUDIT_FILE" ]; then
    echo "  PASS: Audit log exists and has entries"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Audit log missing or empty"
    FAIL=$((FAIL + 1))
fi

TOTAL=$((TOTAL + 1))
if [ -n "$AUDIT_FILE" ] && python3 "$SCRIPT_DIR/verify_audit.py" "$AUDIT_FILE" > /dev/null 2>&1; then
    echo "  PASS: Audit hash chain is valid"
    PASS=$((PASS + 1))
else
    echo "  FAIL: Audit hash chain verification failed"
    FAIL=$((FAIL + 1))
fi

# ── Summary ───────────────────────────────────────────────────────────────

echo ""
echo "=== Results: $PASS/$TOTAL tests passed ==="
if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
