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
    echo "  -j, --jupyter         Start JupyterLab instead of a shell (exposes port 8888)"
    echo "  -p, --proxy           Pass through HTTP_PROXY, HTTPS_PROXY, NO_PROXY from host"
    echo "  -c, --ca FILE         Mount a CA certificate for corporate proxy"
    echo "  -r, --regulated FILE  Launch in regulated environment mode using the specified .env file"
    echo "  --relay FILE          Start the relay proxy using the specified .env file"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                                    # Mount current dir, interactive shell"
    echo "  $(basename "$0") ~/projects/engagement              # Mount specific dir"
    echo "  $(basename "$0") -j                                 # Start JupyterLab on port 8888"
    echo "  $(basename "$0") -p -c corp-ca.crt                  # Corporate proxy with custom CA"
    echo "  $(basename "$0") -r regulated.env                   # Regulated environment mode"
    echo "  $(basename "$0") -r regulated.env -c corp-ca.crt    # Regulated + custom CA"
    echo "  $(basename "$0") --relay relay.env                  # Start relay proxy for tunnelled access"
    echo "  $(basename "$0") --relay relay.env -c corp-ca.crt   # Relay proxy with custom CA"
}

WORKSPACE="$(pwd)"
JUPYTER=false
PROXY=false
CA_CERT=""
REGULATED_ENV=""
RELAY_ENV=""

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
        -r|--regulated)
            REGULATED_ENV="$2"
            shift 2
            ;;
        --relay)
            RELAY_ENV="$2"
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

# --- Regulated environment mode ---
if [ -n "$REGULATED_ENV" ]; then
    if [ ! -f "$REGULATED_ENV" ]; then
        echo "Error: Regulated environment file not found: ${REGULATED_ENV}"
        exit 1
    fi

    REGULATED_ENV="$(cd "$(dirname "$REGULATED_ENV")" && pwd)/$(basename "$REGULATED_ENV")"

    # Read the env file and pass variables to the container
    DOCKER_ARGS+=("-e" "DEEPCYBER_REGULATED=true")
    DOCKER_ARGS+=("--env-file" "${REGULATED_ENV}")

    # Extract CA_CERT_PATH from the env file if set
    ENV_CA_CERT=$(grep -E '^CA_CERT_PATH=' "$REGULATED_ENV" | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [ -n "$ENV_CA_CERT" ] && [ -z "$CA_CERT" ]; then
        CA_CERT="$ENV_CA_CERT"
    fi

    # Extract proxy settings and enable proxy passthrough
    ENV_HTTP_PROXY=$(grep -E '^HTTP_PROXY=' "$REGULATED_ENV" | cut -d= -f2-)
    if [ -n "$ENV_HTTP_PROXY" ]; then
        PROXY=true
    fi
fi

# --- Proxy passthrough ---
if [ "$PROXY" = true ]; then
    DOCKER_ARGS+=("-e" "HTTP_PROXY" "-e" "HTTPS_PROXY" "-e" "NO_PROXY")
fi

# --- CA certificate ---
if [ -n "$CA_CERT" ]; then
    if [ ! -f "$CA_CERT" ]; then
        echo "Error: CA certificate not found: ${CA_CERT}"
        exit 1
    fi
    CA_CERT="$(cd "$(dirname "$CA_CERT")" && pwd)/$(basename "$CA_CERT")"
    DOCKER_ARGS+=("--user" "root" "-v" "${CA_CERT}:/corp-ca/corp-ca.crt:ro")
fi

# --- Relay proxy mode ---
if [ -n "$RELAY_ENV" ]; then
    if [ ! -f "$RELAY_ENV" ]; then
        echo "Error: Relay environment file not found: ${RELAY_ENV}"
        exit 1
    fi

    RELAY_ENV="$(cd "$(dirname "$RELAY_ENV")" && pwd)/$(basename "$RELAY_ENV")"
    DOCKER_ARGS+=("--env-file" "${RELAY_ENV}")

    # Extract relay port (default 8443)
    RELAY_PORT=$(grep -E '^RELAY_PORT=' "$RELAY_ENV" | cut -d= -f2- | tr -d '"' | tr -d "'")
    RELAY_PORT="${RELAY_PORT:-8443}"
    DOCKER_ARGS+=("-p" "${RELAY_PORT}:${RELAY_PORT}")

    # Extract CA_CERT_PATH from relay env if set and not already specified
    ENV_CA_CERT=$(grep -E '^CA_CERT_PATH=' "$RELAY_ENV" | cut -d= -f2- | tr -d '"' | tr -d "'")
    if [ -n "$ENV_CA_CERT" ] && [ -z "$CA_CERT" ]; then
        CA_CERT="$ENV_CA_CERT"
    fi

    echo "Starting DeepCyber relay proxy on port ${RELAY_PORT}..."
    echo "Run 'cloudflared tunnel --url http://localhost:${RELAY_PORT}' to expose via Cloudflare Tunnel."
    echo ""
    docker run "${DOCKER_ARGS[@]}" "$IMAGE" python /home/deepcyber/scripts/relay/relay_proxy.py
    exit 0
fi

# --- Launch ---
if [ "$JUPYTER" = true ]; then
    DOCKER_ARGS+=("-p" "8888:8888")
    docker run "${DOCKER_ARGS[@]}" "$IMAGE" jupyter lab --ip=0.0.0.0 --no-browser --notebook-dir=/home/deepcyber
else
    docker run "${DOCKER_ARGS[@]}" "$IMAGE"
fi
