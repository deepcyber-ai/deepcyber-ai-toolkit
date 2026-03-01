#!/bin/bash
set -e

# --- Corporate CA certificate injection ---
if [ -f /corp-ca/corp-ca.crt ]; then
    cp /corp-ca/corp-ca.crt /usr/local/share/ca-certificates/
    update-ca-certificates
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
fi

# --- Regulated mode ---
if [ "${DEEPCYBER_REGULATED}" = "true" ]; then
    echo "============================================"
    echo "  DeepCyber — REGULATED ENVIRONMENT MODE"
    echo "============================================"
    echo "  Engagement:      ${ENGAGEMENT_ID:-UNSET}"
    echo "  Tester:          ${TESTER_NAME:-unknown}"
    echo "  Client:          ${CLIENT_NAME:-unknown}"
    echo "  Classification:  ${CLASSIFICATION:-INTERNAL}"
    echo "  API Base:        ${OPENAI_API_BASE:-not set}"
    echo "  Model:           ${OPENAI_MODEL_NAME:-not set}"
    echo "============================================"

    # Disable telemetry for all tools
    export PROMPTFOO_DISABLE_TELEMETRY=1
    export DO_NOT_TRACK=1
    export DEEPEVAL_TELEMETRY_OPT_OUT=1
    export GUARDRAILS_NO_TELEMETRY=1
    export HF_HUB_DISABLE_TELEMETRY=1
    export POSTHOG_DISABLED=1
    export SCARF_NO_ANALYTICS=1

    # Initialise audit log
    export AUDIT_LOG="/home/deepcyber/results/audit.log"
    mkdir -p /home/deepcyber/results
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    {
        echo "=== DeepCyber Audit Log ==="
        echo "Session started: ${TIMESTAMP}"
        echo "Engagement: ${ENGAGEMENT_ID:-UNSET}"
        echo "Tester: ${TESTER_NAME:-unknown}"
        echo "Client: ${CLIENT_NAME:-unknown}"
        echo "Classification: ${CLASSIFICATION:-INTERNAL}"
        echo "API Base: ${OPENAI_API_BASE:-not set}"
        echo "Model: ${OPENAI_MODEL_NAME:-not set}"
        echo "==========================="
    } >> "${AUDIT_LOG}"

    echo ""
    echo "Telemetry:  DISABLED for all tools"
    echo "Audit log:  ${AUDIT_LOG}"
    echo ""
fi

# --- Entrypoint ---
if [ $# -gt 0 ]; then
    exec "$@"
elif [ -t 0 ]; then
    exec /bin/bash
else
    exec jupyter lab --ip=0.0.0.0 --no-browser --notebook-dir=/home/deepcyber
fi
