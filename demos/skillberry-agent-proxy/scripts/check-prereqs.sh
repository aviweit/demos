#!/usr/bin/env bash
# Preflight checks for the skillberry-agent-proxy demo.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

errors=0

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        fail "Required command not found: $1"
        errors=$((errors + 1))
    else
        ok "$1"
    fi
}

info "Checking required commands..."
require_cmd docker
require_cmd curl
require_cmd jq
require_cmd envsubst

info "Checking docker compose..."
if docker compose version &>/dev/null; then
    ok "docker compose v2"
else
    fail "docker compose v2 not available (docker compose version failed)"
    errors=$((errors + 1))
fi

info "Checking Praxis binary..."
PRAXIS="$(resolve_praxis_bin)"
if [[ -z "${PRAXIS}" ]]; then
    fail "Praxis binary not found. Set PRAXIS_BIN or PRAXIS_ROOT, or add praxis to PATH."
    errors=$((errors + 1))
elif [[ ! -x "${PRAXIS}" ]]; then
    fail "Praxis binary is not executable: ${PRAXIS}"
    errors=$((errors + 1))
else
    ok "praxis: ${PRAXIS}"
fi

info "Checking environment variables..."
if [[ -z "${SPAPRAXIS_API_KEY:-}" ]]; then
    fail "SPAPRAXIS_API_KEY is not set"
    errors=$((errors + 1))
else
    ok "SPAPRAXIS_API_KEY is set"
fi

if [[ -z "${SPAPRAXIS_LITELLMPROXY:-}" ]]; then
    fail "SPAPRAXIS_LITELLMPROXY is not set (host:port)"
    errors=$((errors + 1))
else
    ok "SPAPRAXIS_LITELLMPROXY=${SPAPRAXIS_LITELLMPROXY}"
fi

info "Checking port availability..."
for p in "${PRAXIS_PORT}" "${STORE_PORT}" "${WORKER_PORT}"; do
    if port_in_use "${p}"; then
        fail "Port ${p} is already in use"
        errors=$((errors + 1))
    else
        ok "Port ${p} is free"
    fi
done

if [[ ${errors} -gt 0 ]]; then
    die "Preflight failed with ${errors} error(s)"
fi

ok "All preflight checks passed"
