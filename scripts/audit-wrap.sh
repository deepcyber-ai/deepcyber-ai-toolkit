#!/bin/bash
# Audit wrapper — logs every command execution with timestamp, user, and project ID.
# Source this script or use it as a prefix: audit-wrap.sh <command> [args...]

AUDIT_LOG="${AUDIT_LOG:-/home/deepcyber/results/audit.log}"

audit_log() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${timestamp} | ${PROJECT_ID:-UNSET} | ${TESTER_NAME:-unknown} | $*" >> "${AUDIT_LOG}"
}

if [ $# -gt 0 ]; then
    audit_log "EXEC: $*"
    "$@"
    EXIT_CODE=$?
    audit_log "EXIT: $* (code=${EXIT_CODE})"
    exit ${EXIT_CODE}
fi
