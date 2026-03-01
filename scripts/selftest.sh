#!/bin/bash
set -e

echo "=== DeepCyber Self-Test ==="

echo "Proxy configuration:"
echo "  HTTP_PROXY=${HTTP_PROXY:-<not set>}"
echo "  HTTPS_PROXY=${HTTPS_PROXY:-<not set>}"
echo "  NO_PROXY=${NO_PROXY:-<not set>}"

echo "Testing HTTPS connectivity to api.openai.com..."
if curl -s -o /dev/null -w "%{http_code}" --head https://api.openai.com | grep -q "^[23]"; then
    echo "  HTTPS connectivity: OK"
else
    echo "  HTTPS connectivity: FAILED (proxy may not be configured)"
fi

echo "=== Self-test complete ==="
