# kubernetools/mcp-server

Container image for the [kubernetools](https://github.com/kubernetools/docgen) MCP server.

**Registry:** `ghcr.io/kubernetools/mcp-server`

## Quick start

```bash
podman run -d \
  -p 3000:3000 \
  -e K8S_VERSIONS=v1.32,v1.33 \
  ghcr.io/kubernetools/mcp-server:latest
```

## Configuration

| Parameter | Mechanism | Description |
|-----------|-----------|-------------|
| `K8S_VERSIONS` | env var | Comma-separated list of Kubernetes versions to serve docs for (e.g. `v1.32,v1.33`). Defaults to `v1.33`. |
| `GITHUB_TOKEN` | env var | GitHub personal access token. Optional; increases API rate limits when fetching Kubernetes API docs. |
| `RUST_LOG` | env var | Log level filter (e.g. `info`, `debug`, `mcp=debug`). |
| Port | `--publish` | The server listens on port `3000`. |

## Health check

`GET /healthz` on port 3000.

- Returns `503` while Kubernetes API docs are loading.
- Returns `200` once the server is ready to handle requests.

Use this endpoint for startup, readiness, and liveness probes.

## Examples

### Multiple Kubernetes versions

```bash
podman run -d \
  -p 3000:3000 \
  -e K8S_VERSIONS=v1.31,v1.32,v1.33 \
  -e GITHUB_TOKEN=ghp_... \
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
