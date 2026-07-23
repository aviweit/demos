# Skillberry Agent Proxy — Praxis Agentic Gateway

A fully automated demo of **Praxis** as an agentic gateway for the Skillberry
Agent platform. Praxis injects skill configuration and LLM policy into every
request, routes to the Skillberry Worker (ReAct tool loop), and handles
credential injection on the LLM egress path.

## What it shows

| Concern | Demo behavior |
|---------|---------------|
| Client | `emulate_client.py` sends an OpenAI-compatible chat completion |
| Gateway | Praxis on localhost:7000 — skill config injection + LLM routing |
| Worker | FastAPI service (ReAct loop) on localhost:7010 inside Docker |
| Store | Skill resolution + tool definitions on localhost:8000 inside Docker |
| LLM | Proxied through Praxis llm-egress (localhost:8081) → LiteLLM |

## Architecture

```text
                              ┌─────────────────────┐
     ┌─────────┐             │       Praxis        │
     │  User   │────────────▸│  ┌───────────────┐  │
     └─────────┘             │  │   Ingress     │  │
                             │  │   (:7000)     │  │
                             │  └───────┬───────┘  │
                             │          │          │
                             └──────────┼──────────┘
                                        │
                                        v
┌───────────────┐        ┌──────────────────────────┐
│     Store     │◂ ─ ─ ─ │    Skillberry Agent      │
│    (:8000)    │         │       (:7010)            │
│  ┌─────────┐  │         │  ┌──────────────────┐   │
│  │  tools  │  │         │  │  Business Logic  │   │
│  │  skills │  │         │  │  (ReAct loop)    │   │
│  └─────────┘  │         │  └────────┬─────────┘   │
└───────────────┘         └───────────┼─────────────┘
                                      │
                             ┌────────┼──────────┐
                             │        v          │
                             │  ┌───────────────┐│
                             │  │   Egress      ││
                             │  │   (:8081)     ││
                             │  └───────┬───────┘│
                             │       Praxis      │
                             └──────────┼────────┘
                                        │
                                        v
                             ┌───────────────────┐
                             │       LLM         │
                             │  (LiteLLM Proxy)  │
                             └───────────────────┘
```

## Prerequisites

- **Platform:** Linux or macOS
- **Docker** with `docker compose` v2 (ships with Docker Desktop / docker-ce)
- **Praxis** binary built from source (`cargo build --package praxis-proxy`)
- **Python 3.10+** with `litellm` installed (`pip install litellm`)
- **curl**, **jq**, **envsubst** (`brew install gettext` on macOS)

## Quick start

```bash
# Set required environment variables
export SPAPRAXIS_API_KEY="<your-llm-provider-key>"
export SPAPRAXIS_LITELLMPROXY="<your-litellm-proxy-host:port>"

# Optional (defaults shown)
export SPAPRAXIS_MODEL="aws/gpt-oss-120b"
export SPAPRAXIS_TEMPERATURE="0.0"

# Run the full demo
./scripts/run-demo.sh
```

The script will:
1. Check all prerequisites and port availability
2. Start the Skillberry Store container (pulls from GHCR)
3. Import the demo skill into the store
4. Start the Skillberry Worker container (builds locally)
5. Start Praxis on the host with the rendered config
6. Run the client emulator and print the agent's response

## Stopping

```bash
./scripts/stop-demo.sh
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `SPAPRAXIS_API_KEY` | — | LLM provider API key (required) |
| `SPAPRAXIS_LITELLMPROXY` | — | LiteLLM proxy host:port (required) |
| `SPAPRAXIS_MODEL` | `aws/gpt-oss-120b` | Model name for all LLM calls |
| `SPAPRAXIS_TEMPERATURE` | `0.0` | Temperature for all LLM calls |
| `PRAXIS_BIN` | auto-detected | Path to Praxis binary |
| `PRAXIS_ROOT` | `~/praxis` | Praxis source root (for binary lookup) |

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Store + Worker container definitions |
| `worker/Dockerfile` | Worker image (clones from GitHub, installs deps) |
| `praxis.yaml.tmpl` | Praxis pipeline template (expanded by envsubst) |
| `skills/praxis-demo-hello-world/` | Demo skill (SKILL.md + 2 Python tools) |
| `scripts/run-demo.sh` | Main entry point — full orchestration |
| `scripts/stop-demo.sh` | Tear down all services |
| `scripts/check-prereqs.sh` | Preflight validation |
| `scripts/lib.sh` | Shared utilities (banners, port checks) |
| `scripts/emulate_client.py` | Client that sends a request through the pipeline |

## Rebuilding the worker

To pull latest worker code from GitHub:

```bash
docker compose build --no-cache worker
```
