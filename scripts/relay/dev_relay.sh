#!/bin/bash
set -e

# ── Configuration ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

MOCK_PORT="${MOCK_PORT:-9999}"
RELAY_PORT="${RELAY_PORT:-8443}"
RELAY_SECRET="${RELAY_SECRET:-mysecret}"
JWT_TOKEN="${JWT_TOKEN:-dev-jwt-token}"
ALLOWED_PATHS="${ALLOWED_PATHS:-}"
BLOCKED_PATHS="${BLOCKED_PATHS:-/admin}"

# ── Cleanup ───────────────────────────────────────────────────────────────

cleanup() {
    echo ""
    echo "Shutting down..."
    [ -n "$MOCK_PID" ] && kill "$MOCK_PID" 2>/dev/null || true
    [ -n "$RELAY_PID" ] && kill "$RELAY_PID" 2>/dev/null || true
    wait "$MOCK_PID" 2>/dev/null || true
    wait "$RELAY_PID" 2>/dev/null || true
    echo "Done."
}
trap cleanup EXIT INT TERM

# ── Port check ────────────────────────────────────────────────────────────

for PORT in $MOCK_PORT $RELAY_PORT; do
    if lsof -ti :"$PORT" > /dev/null 2>&1; then
        echo "ERROR: Port $PORT is already in use."
        exit 1
    fi
done

# ── Start mock echo target ───────────────────────────────────────────────

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
        }, indent=2)
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

TARGET_API="http://127.0.0.1:$MOCK_PORT" \
RELAY_PORT="$RELAY_PORT" \
RELAY_SECRET="$RELAY_SECRET" \
JWT_TOKEN="$JWT_TOKEN" \
ALLOWED_PATHS="$ALLOWED_PATHS" \
BLOCKED_PATHS="$BLOCKED_PATHS" \
python3 "$SCRIPT_DIR/relay_proxy.py" &
RELAY_PID=$!

# ── Wait for readiness ───────────────────────────────────────────────────

for i in $(seq 1 25); do
    if curl -s -o /dev/null "http://127.0.0.1:$RELAY_PORT/__relay/health" 2>/dev/null; then
        break
    fi
    sleep 0.2
done

echo ""
echo "Mock echo target listening on http://127.0.0.1:$MOCK_PORT"
echo "Relay proxy listening on     http://127.0.0.1:$RELAY_PORT"
echo ""
echo "Try:"
echo "  curl -s -H 'X-Relay-Secret: $RELAY_SECRET' http://localhost:$RELAY_PORT/v1/chat/completions | python3 -m json.tool"
echo ""
echo "Press Ctrl-C to stop."
echo ""

wait
