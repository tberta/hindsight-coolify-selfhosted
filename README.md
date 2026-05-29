# Hindsight — Coolify deployment

Self-hosted [Hindsight](https://hindsight.vectorize.io) (memory layer for AI tools)
as a single Coolify resource, with its own bundled PostgreSQL.

## What's in the stack

| Service | Image | Port | Role |
|---|---|---|---|
| `postgres` | `pgvector/pgvector:pg17` | 5432 (internal) | Database with the `vector` + `pg_trgm` extensions |
| `hindsight-api` | `ghcr.io/vectorize-io/hindsight-api:latest` | 8888 | API + MCP server + worker; runs DB migrations on startup |
| `hindsight-control-plane` | `ghcr.io/vectorize-io/hindsight-control-plane:latest` | 9999 | Web UI |

Embeddings and reranking run **locally inside the API container** (no extra API
keys), so the API container wants roughly **2–4 GB RAM**. The first start
downloads the models into a persistent cache volume.

LLM inference uses the **`anthropic`** provider via an API key
(`HINDSIGHT_API_LLM_API_KEY`). The provider is configurable — see the allowed
list in `.env.example`.

> Note on `claude-code`: Vectorize documents it as *personal/local use only*.
> In a remote container it needs your personal Claude Max/Pro OAuth credentials
> bind-mounted as single files, a host-installed `claude` CLI, post-deploy
> chmod/symlink fixups, and the all-in-one image — and it breaks on token
> expiry. That's why this stack defaults to `anthropic` (API key). See
> [hindsight#1480](https://github.com/vectorize-io/hindsight/issues/1480).

## Deploy on Coolify

1. **Push this repo** to GitHub/GitLab (see below).
2. In Coolify: **+ New → Resource → Docker Compose** (or *Public/Private
   Repository* → Build Pack: **Docker Compose**). Point it at this repo;
   compose path `docker-compose.yml`.
3. **Set environment variables** (Resource → Environment Variables) using
   `.env.example` as the reference. At minimum:
   - `POSTGRES_PASSWORD`
   - `HINDSIGHT_API_LLM_API_KEY`
   - `HINDSIGHT_CP_ACCESS_KEY` (UI login)
   - `HINDSIGHT_API_TENANT_API_KEY` (data-plane API key, see below)
4. **Deploy.** Coolify auto-generates domains for the two `SERVICE_FQDN_*`
   variables and wires up its reverse proxy + TLS:
   - `SERVICE_FQDN_HINDSIGHTUI_9999` → the web UI
   - `SERVICE_FQDN_HINDSIGHTAPI_8888` → the API / MCP endpoint
   You can replace the generated domains with your own under **Service → Domains**.
5. First boot: `hindsight-api` waits for Postgres to be healthy, runs migrations,
   then downloads the local embedding/reranker models — give it a few minutes.

### Generate the secrets

```bash
openssl rand -hex 24   # POSTGRES_PASSWORD
openssl rand -hex 24   # HINDSIGHT_CP_ACCESS_KEY
openssl rand -hex 24   # HINDSIGHT_API_TENANT_API_KEY
```

## Data-plane API key gate (on by default)

The API/MCP endpoint is internet-facing, so this stack enables an API key gate
by default: every request to the API must send `Authorization: Bearer
<HINDSIGHT_API_TENANT_API_KEY>`. The control plane reuses the same key
(`HINDSIGHT_CP_DATAPLANE_API_KEY`), so you only set **`HINDSIGHT_API_TENANT_API_KEY`**
once and external clients (e.g. an MCP integration) use that same value.

Both the API and the control plane fail fast on startup if it isn't set.

To **disable** the gate, set `HINDSIGHT_API_TENANT_EXTENSION` to an empty value
(you'll then also want to clear `HINDSIGHT_CP_DATAPLANE_API_KEY`).

## Local test (optional, requires Docker)

```bash
cp .env.example .env   # then edit the secrets
docker compose up
# UI:  http://localhost:9999   (set ports temporarily if testing outside Coolify)
# API: http://localhost:8888
```

> The committed compose uses `expose:` (Coolify proxies it). To test directly on
> a workstation, temporarily add `ports:` mappings for 9999/8888.

## References

- Installation: https://hindsight.vectorize.io/developer/installation
- Configuration (all env vars): https://hindsight.vectorize.io/developer/configuration
