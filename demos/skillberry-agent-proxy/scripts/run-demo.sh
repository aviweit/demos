#!/usr/bin/env bash
# Skillberry Agent Proxy — full automated demo.
# Starts all services, imports the skill, and runs the client emulator.
#
# Usage:
#   export SPAPRAXIS_API_KEY="<your-key>"
#   export SPAPRAXIS_LITELLMPROXY="<host:port>"
#   ./scripts/run-demo.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

# Defaults for optional vars
export SPAPRAXIS_MODEL="${SPAPRAXIS_MODEL:-aws/gpt-oss-120b}"
export SPAPRAXIS_TEMPERATURE="${SPAPRAXIS_TEMPERATURE:-0.0}"
export SKILL_NAME="${SKILL_NAME:-praxis-demo-hello-world}"
export SKILL_UUID="${SKILL_UUID:-}"
export ENABLE_THINK_LOGS="${ENABLE_THINK_LOGS:-false}"
export USE_AGENT_TOOLS="${USE_AGENT_TOOLS:-false}"
export USE_AGENT_PROMPTS="${USE_AGENT_PROMPTS:-true}"
export MCP_PROMPTS_POSITION="${MCP_PROMPTS_POSITION:-postfix}"
export REACT_RECURSION_LIMIT="${REACT_RECURSION_LIMIT:-20}"
export SKILLBERRY_STORE_URL="${SKILLBERRY_STORE_URL:-http://host.docker.internal:8000}"

ensure_artifacts
banner

# ── Cleanup trap ─────────────────────────────────────────────────────────────

cleanup() {
    info "Cleaning up..."
    "${SCRIPT_DIR}/stop-demo.sh" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# ══════════════════════════════════════════════════════════════════════════════
section "1/6 Preflight"
cat <<'DESC'
  Checking prerequisites: docker, praxis binary, required env vars,
  and port availability.
DESC

source "${SCRIPT_DIR}/check-prereqs.sh"

# ══════════════════════════════════════════════════════════════════════════════
section "2/6 Start Store"
cat <<'DESC'
  Starting the Skillberry Store container (ghcr.io/skillberry-ai/skillberry-store).
  The store provides skill resolution and tool definitions to the worker.
DESC

docker compose -f "${DEMO_DIR}/docker-compose.yml" up -d store
wait_for_health "http://localhost:${STORE_PORT}/health" "Skillberry Store" 60

# ══════════════════════════════════════════════════════════════════════════════
section "3/6 Import Skill"
cat <<'DESC'
  Importing the demo skill (praxis-demo-hello-world) into the store.
  This skill has two tools: praxis_demo_greet and praxis_demo_echo.
DESC

# Check if skill already exists in the store
if curl -sf "http://localhost:${STORE_PORT}/skills/praxis-demo-hello-world" >/dev/null 2>&1; then
    info "Skill 'praxis-demo-hello-world' already exists in the store — skipping import"
else
    # Path as seen inside the store container (volume-mounted in docker-compose.yml)
    SKILL_DIR_CONTAINER="/demo-skills/praxis-demo-hello-world"

    curl -sf -X POST "http://localhost:${STORE_PORT}/skills/import-anthropic" \
        -F "source_type=folder" \
        -F "folder_path=${SKILL_DIR_CONTAINER}" \
        -F "snippet_mode=file" | jq .
fi

info "Verifying skill import..."
curl -sf "http://localhost:${STORE_PORT}/skills/praxis-demo-hello-world" | jq '.name'
ok "Skill imported successfully"

# ══════════════════════════════════════════════════════════════════════════════
section "4/6 Start Worker"
cat <<'DESC'
  Starting the Skillberry Worker container. The worker runs the agentic
  ReAct loop — it receives requests from Praxis, resolves tools from the
  store, and makes LLM calls through Praxis's llm-egress listener.
DESC

docker compose -f "${DEMO_DIR}/docker-compose.yml" up -d worker
wait_for_health "http://localhost:${WORKER_PORT}/health" "Skillberry Worker" 60

# ══════════════════════════════════════════════════════════════════════════════
section "5/6 Start Praxis"
cat <<'DESC'
  Starting Praxis on the host. Praxis serves as the agentic gateway:
  - Port 7000: client ingress (injects skill config headers → worker)
  - Port 8081: LLM egress (credential injection → LiteLLM proxy)
DESC

PRAXIS="$(resolve_praxis_bin)"

# Derive upstream hostname and detect TLS
export SPAPRAXIS_LITELLMPROXY_HOST="${SPAPRAXIS_LITELLMPROXY%%:*}"
LITELLM_PORT="${SPAPRAXIS_LITELLMPROXY##*:}"

info "Expanding praxis.yaml.tmpl..."
envsubst < "${TEMPLATE}" > "${RUNTIME_CONFIG}"

# Strip TLS block when upstream is plain HTTP
if [[ "${LITELLM_PORT}" != "443" ]]; then
    sed -i'' -e '/# __TLS_BEGIN__/,/# __TLS_END__/d' "${RUNTIME_CONFIG}"
    info "Plain HTTP upstream (port ${LITELLM_PORT})"
else
    sed -i'' -e '/# __TLS_BEGIN__/d; /# __TLS_END__/d' "${RUNTIME_CONFIG}"
    info "HTTPS upstream (TLS enabled)"
fi

info "Starting Praxis..."
RUST_LOG="${RUST_LOG:-praxis_filter=info}" "${PRAXIS}" --config "${RUNTIME_CONFIG}" \
    > "${LOG_FILE}" 2>&1 &
echo $! > "${PID_FILE}"

wait_for_port "${PRAXIS_PORT}" "Praxis" 15

# ══════════════════════════════════════════════════════════════════════════════
section "6/6 Run Client"
cat <<'DESC'
  Sending a chat completion request through the full pipeline:
  Client → Praxis (7000) → Worker (7010) → Praxis LLM-egress (8081) → LiteLLM

  The agent should discover its tools (greet + echo) and respond.
DESC

export OPENAI_API_BASE="http://localhost:${PRAXIS_PORT}/v1"
export OPENAI_API_KEY="not-used"

# Set up Python venv for the client
VENV_DIR="${DEMO_DIR}/.venv"
if [[ ! -d "${VENV_DIR}" ]]; then
    info "Creating virtual environment..."
    python3 -m venv "${VENV_DIR}"
fi
if ! "${VENV_DIR}/bin/python" -c "import litellm" 2>/dev/null; then
    info "Installing litellm into .venv..."
    "${VENV_DIR}/bin/pip" install --quiet --upgrade pip
    "${VENV_DIR}/bin/pip" install --quiet litellm
fi

"${VENV_DIR}/bin/python" "${SCRIPT_DIR}/emulate_client.py"

# ══════════════════════════════════════════════════════════════════════════════
printf '\n'
printf '\033[1;32m'
cat <<'DONE'
  ┌─────────────────────────────────────────────┐
  │          Demo completed successfully!        │
  │                                             │
  │   Store:   http://localhost:8000            │
  │   Worker:  http://localhost:7010            │
  │   Praxis:  http://localhost:7000            │
  │                                             │
  │   Stop:    ./scripts/stop-demo.sh           │
  └─────────────────────────────────────────────┘
DONE
printf '\033[0m\n'

# Don't cleanup on success — leave services running for manual exploration
trap - EXIT INT TERM
