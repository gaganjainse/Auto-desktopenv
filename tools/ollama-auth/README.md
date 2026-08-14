# Ollama auth — API-key proxy

Ollama has **no built-in auth**. This tool puts a Caddy reverse proxy in front of
the local Ollama so every request must carry an API key, and forces the raw
Ollama API to bind loopback-only.

- **Raw Ollama** stays at `127.0.0.1:11434` (loopback only, systemd drop-in).
- **Proxy** listens at `127.0.0.1:11435` and requires `X-API-Key: <key>`.
- The key is generated once at `~/.config/shesh/ollama/api.key` (0600).
- Shesh clients read `OLLAMA_URL` + `OLLAMA_API_KEY` from
  `~/.config/shesh/ollama/env` (systemd `EnvironmentFile` on the MCP units).

## Install

```bash
bash tools/ollama-auth/setup-ollama-auth.sh
```

Run it once after `setup install` (or `install-shesh-stack.sh`, which calls it
automatically). It is idempotent.

## Test

```bash
curl -s http://127.0.0.1:11435/api/tags                          # -> 401
curl -s -H "X-API-Key: $(cat ~/.config/shesh/ollama/api.key)" \
     http://127.0.0.1:11435/api/tags                             # -> models
```
