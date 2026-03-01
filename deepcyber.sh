#!/bin/bash
set -e

IMAGE="deepcyber-ai-toolkit:1.0"
CONTAINER_MOUNT="/workspace"

usage() {
    echo "Usage: $(basename "$0") [OPTIONS] [WORKSPACE_PATH]"
    echo ""
    echo "Launch the DeepCyber AI Red Team Toolkit container."
    echo ""
    echo "Arguments:"
    echo "  WORKSPACE_PATH    Host directory to mount at ${CONTAINER_MOUNT} (default: current directory)"
    echo ""
    echo "Options:"
    echo "  -j, --jupyter     Start JupyterLab instead of a shell (exposes port 8888)"
    echo "  -p, --proxy       Pass through HTTP_PROXY, HTTPS_PROXY, NO_PROXY from host"
    echo "  -c, --ca FILE     Mount a CA certificate for corporate proxy"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                        # Mount current dir, interactive shell"
    echo "  $(basename "$0") ~/projects/engagement  # Mount specific dir"
    echo "  $(basename "$0") -j                     # Start JupyterLab on port 8888"
    echo "  $(basename "$0") -p -c corp-ca.crt      # Corporate proxy with custom CA"
}

WORKSPACE="$(pwd)"
JUPYTER=false
PROXY=false
CA_CERT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -j|--jupyter)
            JUPYTER=true
            shift
            ;;
        -p|--proxy)
            PROXY=true
            shift
            ;;
        -c|--ca)
            CA_CERT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            WORKSPACE="$1"
            shift
            ;;
    esac
done

if [ ! -d "$WORKSPACE" ]; then
    echo "Error: ${WORKSPACE} is not a directory"
    exit 1
fi

WORKSPACE="$(cd "$WORKSPACE" && pwd)"

DOCKER_ARGS=("-it" "--rm" "-v" "${WORKSPACE}:${CONTAINER_MOUNT}")

if [ "$PROXY" = true ]; then
    DOCKER_ARGS+=("-e" "HTTP_PROXY" "-e" "HTTPS_PROXY" "-e" "NO_PROXY")
fi

if [ -n "$CA_CERT" ]; then
    if [ ! -f "$CA_CERT" ]; then
        echo "Error: CA certificate not found: ${CA_CERT}"
        exit 1
    fi
    CA_CERT="$(cd "$(dirname "$CA_CERT")" && pwd)/$(basename "$CA_CERT")"
    DOCKER_ARGS+=("--user" "root" "-v" "${CA_CERT}:/corp-ca/corp-ca.crt:ro")
fi

if [ "$JUPYTER" = true ]; then
    DOCKER_ARGS+=("-p" "8888:8888")
    docker run "${DOCKER_ARGS[@]}" "$IMAGE" jupyter lab --ip=0.0.0.0 --no-browser --notebook-dir=/home/deepcyber
else
    docker run "${DOCKER_ARGS[@]}" "$IMAGE"
fi
