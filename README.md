# kubernetools/mcp-server

Container image for the [kubernetools](https://github.com/kubernetools/docgen) MCP server.

**Registry:** `ghcr.io/kubernetools/mcp-server`

## Quick start

### Anonymous mode (local use)

No authentication required; all connections are rate-limited per source IP at the free-tier limit.

```bash
podman run -d \
  -p 3000:3000 \
  -e K8S_VERSIONS=v1.33 \
  ghcr.io/kubernetools/mcp-server:latest
```

### With API key authentication

```bash
# 1. Create a key store file
echo '[{"key":"mykey","tier":"free"}]' > keys.json

# 2. Start the server
podman run -d \
  -p 3000:3000 \
  -v "$(pwd)/keys.json:/keys.json:ro" \
  -e K8S_VERSIONS=v1.33,v1.34,v1.35,v1.36 \
  -e KEY_STORE_PATH=/keys.json \
  ghcr.io/kubernetools/mcp-server:latest
```

## Configuration

| Parameter | Env var | Description |
|-----------|---------|-------------|
| Kubernetes versions | `K8S_VERSIONS` | Comma-separated list of versions to pre-load (e.g. `v1.33,v1.34`). Defaults to `v1.33`. |
| GitHub token | `GITHUB_TOKEN` | Personal access token (no extra scopes needed). Optional; raises the GitHub API rate limit from 60 to 5 000 req/h — recommended when loading multiple versions. |
| Key store | `KEY_STORE_PATH` | Path to the API key JSON file (mount it into the container). When omitted, the server runs in anonymous mode: no auth is required and all connections are rate-limited per source IP at the free-tier limit. |
| Allowed hosts | `ALLOWED_HOSTS` | Comma-separated `Host` header values to accept (e.g. `mcp.example.com,mcp.example.com:443`). When omitted, host validation is disabled — suitable for local development only. Always set this in production to prevent DNS-rebinding attacks. |
| Browser redirect | `BROWSER_REDIRECT_URL` | URL to redirect plain browser GET requests to. MCP clients are detected by `Accept: text/event-stream`; browsers receive `307` to this URL instead. When omitted, browser GETs return `400`. |
| Log level | `RUST_LOG` | Log level filter (e.g. `info`, `debug`, `mcp=debug`). |
| Port | `--publish` | The server listens on port `3000`. |

## Authentication

### API key store

The key store is a flat JSON array loaded once at startup:

```json
[
  { "key": "free-key-abc", "tier": "free" },
  { "key": "paid-key-xyz", "tier": "paid" }
]
```

Every request must include the key in the `Authorization` header:

```
Authorization: Bearer free-key-abc
```

Requests without a valid key receive `401 Unauthorized`.

### Anonymous mode

When `KEY_STORE_PATH` is not set, the server runs without authentication. All connections are accepted and rate-limited per source IP at the free-tier limit. Convenient for local use; do not expose publicly.

### Tiers and rate limits

| Tier | Limit |
|------|-------|
| `free` | 10 requests / minute, burst 10 |
| `paid` | ~1 000 requests / second, burst 1 000 (effectively unlimited) |

Requests that exceed the limit receive `429 Too Many Requests`. Limits are tracked per API key, not per IP.

## Connecting an MCP client

The server implements the [MCP Streamable HTTP transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports#streamable-http). The endpoint is:

```
http://<host>:<port>/[?version=<k8s-version>]
```

The `version` query parameter selects which Kubernetes version to use for the session. If omitted, the first loaded version is used. An unknown version returns `400 Bad Request`.

### Claude Desktop

Add the following to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "kubernetools": {
      "url": "http://localhost:3000/?version=v1.36",
      "headers": {
        "Authorization": "Bearer mykey"
      }
    }
  }
}
```

## Available tools

### `list_resources`

Lightweight discovery — returns one entry per resource, sorted by `(group, kind, api_version)`. Use this first to find kind names.

**Optional filters:** `group` (e.g. `"apps"`, `"core"`), `api_version` (e.g. `"v1"`).

### `get_resource`

Full resource detail — fields, spec, status, and list fields — enough to write a manifest in one call. Required: `kind`. Optional: `group`, `api_version` (defaults to most recent).

Fields with a non-null `type_ref` and empty `sub_fields` should be drilled into with `get_type`.

### `get_type`

Drill into a single composite type referenced via `type_ref` in `get_resource` output. Required: `type_name` (e.g. `"Container"`, `"PodFailurePolicy"`).

### Typical query flow

```
list_resources                          → discover kind names and groups
  └─ get_resource(kind="Deployment")   → see all top-level fields + spec/status
       └─ get_type(type_name="...")    → drill into any complex type_ref
```

## Health check

`GET /healthz` on port 3000.

- Returns `503 Service Unavailable` (body: `loading`) while Kubernetes API docs are loading.
- Returns `200 OK` (body: `ok`) once the server is ready.

This endpoint bypasses authentication and rate limiting.

Use it for startup, readiness, and liveness probes:

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 3000
  failureThreshold: 30   # allow up to 5 min for version loading
  periodSeconds: 10
readinessProbe:
  httpGet:
    path: /healthz
    port: 3000
livenessProbe:
  httpGet:
    path: /healthz
    port: 3000
  initialDelaySeconds: 10
```

## Error responses

| HTTP status | Cause |
|-------------|-------|
| `307 Temporary Redirect` | Browser GET when `BROWSER_REDIRECT_URL` is set |
| `400 Bad Request` | Browser GET when `BROWSER_REDIRECT_URL` is not set, or `version` parameter names a version not loaded at startup |
| `401 Unauthorized` | Missing or invalid `Authorization: Bearer <key>` header |
| `429 Too Many Requests` | Rate limit exceeded for the key's tier |

MCP-level errors (unknown tool name, missing required argument, kind not found) are returned as MCP error content inside a normal `200` response.

## Examples

### Multiple Kubernetes versions

```bash
podman run -d \
  -p 3000:3000 \
  -v "$(pwd)/keys.json:/keys.json:ro" \
  -e K8S_VERSIONS=v1.33,v1.34,v1.35,v1.36 \
  -e GITHUB_TOKEN=ghp_... \
  -e KEY_STORE_PATH=/keys.json \
  ghcr.io/kubernetools/mcp-server:latest
```

### Production setup with host validation

```bash
podman run -d \
  -p 3000:3000 \
  -v "$(pwd)/keys.json:/keys.json:ro" \
  -e K8S_VERSIONS=v1.36 \
  -e KEY_STORE_PATH=/keys.json \
  -e ALLOWED_HOSTS=mcp.example.com,mcp.example.com:443 \
  -e BROWSER_REDIRECT_URL=https://example.com/docs \
  ghcr.io/kubernetools/mcp-server:latest
```

### Debug logging

```bash
podman run -d \
  -p 3000:3000 \
  -e K8S_VERSIONS=v1.33 \
  -e RUST_LOG=debug \
  ghcr.io/kubernetools/mcp-server:latest
```

### Pin to a specific release

```bash
podman run -d \
  -p 3000:3000 \
  -e K8S_VERSIONS=v1.33 \
  ghcr.io/kubernetools/mcp-server:0.1.0
```

## Image

Built on [`registry.access.redhat.com/hi/core-runtime:2.42-openssl`](https://hummingbird-project.io) — a minimal, distroless glibc + OpenSSL runtime. No shell or package manager.
