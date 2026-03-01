#!/bin/bash
set -e

if [ -f /corp-ca/corp-ca.crt ]; then
    cp /corp-ca/corp-ca.crt /usr/local/share/ca-certificates/
    update-ca-certificates
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
fi

if [ $# -gt 0 ]; then
    exec "$@"
elif [ -t 0 ]; then
    exec /bin/bash
else
    exec jupyter lab --ip=0.0.0.0 --no-browser --notebook-dir=/home/deepcyber
fi
