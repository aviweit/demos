#!/usr/bin/env bash
# Shared utilities for the skillberry-agent-proxy demo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACTS_DIR="${DEMO_DIR}/artifacts"
TEMPLATE="${DEMO_DIR}/praxis.yaml.tmpl"
RUNTIME_CONFIG="${ARTIFACTS_DIR}/praxis.runtime.yaml"
PID_FILE="${ARTIFACTS_DIR}/praxis.pid"
LOG_FILE="${ARTIFACTS_DIR}/praxis.log"

PRAXIS_PORT="${PRAXIS_PORT:-7000}"
STORE_PORT="${STORE_PORT:-8000}"
WORKER_PORT="${WORKER_PORT:-7010}"

# ── Display helpers ──────────────────────────────────────────────────────────

info()    { printf '\033[0;36m▸ %s\033[0m\n' "$*"; }
ok()      { printf '\033[0;32m✔ %s\033[0m\n' "$*"; }
fail()    { printf '\033[0;31m✖ %s\033[0m\n' "$*" >&2; }
die()     { fail "$@"; exit 1; }
section() { printf '\n\033[1;35m══ %s ══\033[0m\n\n' "$1"; }
banner()  {
    printf '\033[1m'
    cat <<'BANNER'

  ┌─────────────────────────────────────────────────────┐
  │   Skillberry Agent Proxy — Praxis Agentic Gateway   │
  │                                                     │
  │   Store (:8000) → Worker (:7010) → Praxis (:7000)  │
  └─────────────────────────────────────────────────────┘

BANNER
    printf '\033[0m'
}

# ── Port / process utilities ─────────────────────────────────────────────────

port_in_use() {
    local port="$1"
    if command -v ss &>/dev/null; then
        ss -tlnp 2>/dev/null | grep -q ":${port} "
    elif command -v lsof &>/dev/null; then
        lsof -iTCP:"${port}" -sTCP:LISTEN &>/dev/null
    else
        (echo >/dev/tcp/127.0.0.1/"${port}") 2>/dev/null
    fi
}

wait_for_port() {
    local port="$1" label="${2:-service}" timeout="${3:-30}"
    local elapsed=0
    while ! port_in_use "${port}"; do
        sleep 1
        elapsed=$((elapsed + 1))
        if [[ ${elapsed} -ge ${timeout} ]]; then
            die "${label} did not start within ${timeout}s (port ${port})"
        fi
    done
    ok "${label} is up on port ${port}"
}

wait_for_health() {
    local url="$1" label="${2:-service}" timeout="${3:-30}"
    local elapsed=0
    while ! curl -sf "${url}" >/dev/null 2>&1; do
        sleep 1
        elapsed=$((elapsed + 1))
        if [[ ${elapsed} -ge ${timeout} ]]; then
            die "${label} health check failed after ${timeout}s (${url})"
        fi
    done
    ok "${label} is healthy"
}

ensure_artifacts() { mkdir -p "${ARTIFACTS_DIR}"; }

resolve_praxis_bin() {
    if [[ -n "${PRAXIS_BIN:-}" ]]; then
        echo "${PRAXIS_BIN}"
    elif [[ -x "${PRAXIS_ROOT:-$HOME/praxis}/target/debug/praxis" ]]; then
        echo "${PRAXIS_ROOT:-$HOME/praxis}/target/debug/praxis"
    elif command -v praxis &>/dev/null; then
        command -v praxis
    else
        echo ""
    fi
}
