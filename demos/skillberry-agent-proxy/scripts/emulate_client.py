"""
emulate_client.py – Send a chat completion through the Skillberry Agent Proxy.

The request flows: Client → Praxis (7000) → Worker (7010) → Praxis LLM-egress (8081) → LiteLLM

Praxis owns all LLM routing: model, temperature, and API key are injected by
Praxis and the client-supplied values are ignored.
"""

import os

from litellm import completion

os.environ.setdefault("OPENAI_API_BASE", "http://localhost:7000/v1")
os.environ.setdefault("OPENAI_API_KEY", "not-used")

response = completion(
    model="openai/fake-model",
    messages=[{"role": "user", "content": "Show me your tools"}],
    extra_headers={
        "skillberry-context-env_id": "praxis-demo-env"
    },
)

print(response.choices[0].message.content)
