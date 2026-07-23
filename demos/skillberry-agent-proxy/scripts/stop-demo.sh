#!/usr/bin/env bash
# Stop all services started by run-demo.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

info "Stopping Praxis..."
if [[ -f "${PID_FILE}" ]]; then
    PID="$(cat "${PID_FILE}")"
    if kill -0 "${PID}" 2>/dev/null; then
        kill "${PID}" 2>/dev/null || true
        sleep 1
        kill -0 "${PID}" 2>/dev/null && kill -9 "${PID}" 2>/dev/null || true
        ok "Praxis stopped (pid ${PID})"
    else
        info "Praxis process already gone (pid ${PID})"
    fi
    rm -f "${PID_FILE}"
else
    info "No Praxis PID file found"
fi

info "Stopping containers..."
docker compose -f "${DEMO_DIR}/docker-compose.yml" down 2>/dev/null || true
ok "Containers stopped"

info "Cleaning artifacts..."
rm -f "${RUNTIME_CONFIG}" "${LOG_FILE}"
ok "Done"
