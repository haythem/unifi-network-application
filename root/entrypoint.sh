#!/bin/bash
set -euo pipefail

# Color Output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Logs
info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Graceful Shutdown
terminate() {
    info "*** Shutting down... ***"
    if [[ -n "$PID" ]]; then
        kill -TERM $PID 2>/dev/null
        wait $PID
    fi
    exit 0
}

trap terminate SIGTERM SIGINT

mkdir -p /config/data /config/logs

if [[ ! -e /config/data/system.properties ]]; then
    if [[ -z "${MONGO_HOST}" ]]; then
        error "*** No MONGO_HOST set, cannot configure database settings. ***"
        exit 2
    else
        info "*** Waiting for MONGO_HOST ${MONGO_HOST} to be reachable. ***"
        DBCOUNT=0
        while true; do
            if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${MONGO_HOST}/${MONGO_PORT}" 2>/dev/null; then
                break
            fi

            DBCOUNT=$((DBCOUNT+1))
            if [[ ${DBCOUNT} -gt 6 ]]; then
                error "*** Defined MONGO_HOST ${MONGO_HOST} is not reachable, cannot proceed. ***"
                exit 3
            fi
            sleep 5
        done

        if [[ -z "${MONGO_AUTHSOURCE}" ]]; then
            AUTHSOURCE=""
        else
            # Note: Escaping the & is safer in sed replacements
            AUTHSOURCE="\&authSource=${MONGO_AUTHSOURCE}"
        fi

        sed -e "s/~MONGO_USER~/${MONGO_USER}/" \
            -e "s/~MONGO_HOST~/${MONGO_HOST}/" \
            -e "s/~MONGO_PORT~/${MONGO_PORT}/" \
            -e "s/~MONGO_DBNAME~/${MONGO_DBNAME}/" \
            -e "s/~MONGO_PASS~/${MONGO_PASS}/" \
            -e "s/~MONGO_TLS~/${MONGO_TLS,,}/" \
            -e "s/~MONGO_AUTHSOURCE~/${AUTHSOURCE}/" \
            /defaults/system.properties > /config/data/system.properties
    fi
fi

# Keystore
if [[ ! -f /config/data/keystore ]]; then
    keytool -genkey -keyalg RSA -alias unifi -keystore /config/data/keystore \
    -storepass aircontrolenterprise -keypass aircontrolenterprise -validity 3650 \
    -keysize 4096 -dname "cn=unifi" -ext san=dns:unifi
fi

JAVA_OPTS=(
    -Xms"${MEM_STARTUP}M"
    -Xmx"${MEM_LIMIT}M"
    -Dlog4j2.formatMsgNoLookups=true
    -Dfile.encoding=UTF-8
    -Djava.awt.headless=true
    -Dapple.awt.UIElement=true
    -XX:+UseParallelGC
    -XX:+ExitOnOutOfMemoryError
    -XX:+CrashOnOutOfMemoryError
    --add-opens java.base/java.lang=ALL-UNNAMED
    --add-opens java.base/java.time=ALL-UNNAMED
    --add-opens java.base/sun.security.util=ALL-UNNAMED
    --add-opens java.base/java.io=ALL-UNNAMED
    --add-opens java.rmi/sun.rmi.transport=ALL-UNNAMED
)

java "${JAVA_OPTS[@]}" -jar /usr/lib/unifi/lib/ace.jar start &

PID=$!
wait $PID

EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    error "*** UniFi exited with code $EXIT_CODE ***"
    exit $EXIT_CODE
fi
