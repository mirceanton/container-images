# TrueNAS MCP Container Image

Container image for [TrueNAS MCP](https://github.com/truenas/truenas-mcp), iXsystems' official MCP
server for TrueNAS, exposed over Streamable HTTP.

## Why a custom image?

`truenas-mcp` is a single stdio-only Go binary (JSON-RPC over stdio, exactly like a
Claude Desktop / Claude Code server) and upstream publishes **no container image**, only
release archives. This image combines the upstream release binary with
[supergateway](https://github.com/supercorp-ai/supergateway), which bridges stdio to
Streamable HTTP, so the server can run as a plain Kubernetes workload behind one HTTP
endpoint:

```
MCP client --(Streamable HTTP /mcp)--> supergateway --(stdio)--> truenas-mcp --(wss)--> TrueNAS
```

Two upstream properties shape the build:

- The released binary is a cgo build **linked against glibc**
  (`PT_INTERP=/lib64/ld-linux-x86-64.so.2`, `DT_NEEDED libc.so.6`), so it cannot run on
  supergateway's own image (`node:*-alpine`, musl only, no glibc loader and no
  `gcompat`). The base here is therefore `node:20-bookworm-slim` - the same Node major as
  upstream's bridge image - with `supergateway` installed from npm using the same flags
  that image's Dockerfile uses.
- Upstream only builds `linux-amd64` (`make build-all`), so **this image is published for
  `linux/amd64` only**.

The release archive is checksum-verified at build time against the `checksums.txt` that
upstream publishes for the same release.

## Usage (Docker)

```bash
docker run --rm -p 8080:8080 \
  -e TRUENAS_URL=192.168.0.31 \
  -e TRUENAS_API_KEY=your-api-key \
  ghcr.io/mirceanton/truenas-mcp:latest
```

- MCP endpoint: `http://localhost:8080/mcp` (Streamable HTTP)
- Health endpoint: `http://localhost:8080/healthz`

```bash
curl -X POST http://localhost:8080/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"probe","version":"1.0"}}}'
```

The container's default command is `supergateway --stdio truenas-mcp --outputTransport
streamableHttp --port 8080 --streamableHttpPath /mcp --healthEndpoint /healthz`
(`ENTRYPOINT` = `supergateway`, these arguments are the `CMD`), so extra arguments can be
appended, e.g. `docker run ... ghcr.io/mirceanton/truenas-mcp:latest --stateful` or
`--apiKey ...`. `/healthz` answers `ok` while the gateway is up; add `--healthCheck server`
if you want it to actually start/ping the MCP server.

## Environment variables

The server is configured entirely through the environment (it also accepts the equivalent
`--truenas-url`, `--api-key`, `--tls-ca`, `--insecure` and `--debug` flags):

| Variable             | Required | Description                                                                                     |
| -------------------- | -------- | ----------------------------------------------------------------------------------------------- |
| `TRUENAS_URL`        | yes      | TrueNAS hostname or IP. The binary dials `wss://$TRUENAS_URL:443/websocket`; `ws://` is refused. |
| `TRUENAS_API_KEY`    | yes      | TrueNAS API key (TrueNAS UI: System Settings -> API Keys).                                      |
| `TRUENAS_TLS_CA`     | no       | Path to a PEM certificate to trust, e.g. an exported TrueNAS self-signed certificate.           |
| `TRUENAS_INSECURE`   | no       | `1` disables TLS verification. Unsafe (MITM); prefer `TRUENAS_TLS_CA`.                          |
| `TRUENAS_MCP_DEBUG`  | no       | `1` logs full request/response bodies (credentials are redacted).                                |

Note that the child process starts connecting and authenticating to TrueNAS as soon as the
gateway spawns it, so a missing/unreachable `TRUENAS_URL` or a bad `TRUENAS_API_KEY` makes
the MCP `initialize` call fail (the gateway reports `MCP server process failed`), while
`/healthz` - which only reflects the gateway - keeps answering `ok`.

## Usage (Kubernetes)

This image is meant to be driven by a single
[`LiteLLMMCPServer`](https://github.com/mirceanton/home-ops) custom resource
(`litellm.home-operations.com/v1alpha1`), which the litellm-operator turns into a
Deployment + ClusterIP Service and registers as an MCP server on the LiteLLM proxy:

```yaml
apiVersion: litellm.home-operations.com/v1alpha1
kind: LiteLLMMCPServer
metadata:
  name: truenas-mcp
  namespace: ai
spec:
  alias: truenas
  proxyRef: litellm
  workload:
    image: ghcr.io/mirceanton/truenas-mcp:0.0.6 #! pin the digest in real manifests
    port: 8080
    path: /mcp
    env:
      - name: TRUENAS_URL
        value: 192.168.0.31
      - name: TRUENAS_INSECURE
        value: "1"
      - name: TRUENAS_API_KEY
        valueFrom:
          secretKeyRef:
            name: litellm-secret
            key: TRUENAS_API_KEY
```

The operator sets no probes for MCP workloads, so `Ready` only proves the Deployment was
created - smoke-test by listing tools through the proxy (`/truenas/mcp/`).

The container runs as root, like upstream's bridge image. If you want a non-root
`securityContext`, the base image already ships a `node` user (uid/gid 1000), and nothing
in this image needs root.

## Included Tools

- `truenas-mcp` - upstream TrueNAS MCP server (stdio)
- `supergateway` - stdio to Streamable HTTP bridge
- `node` / `npm` - Node.js 20 runtime (from `node:20-bookworm-slim`)
- `ca-certificates` - for TLS connections to TrueNAS

## Tags

Same scheme as the other images in this repo: `latest`, `X.Y.Z`, `X.Y`, `X`, `sha-<hash>`
and `date-<date>`. Only `linux/amd64` is built.

## License

This image's Dockerfile and repository tooling are MIT (see the [repo LICENSE](../../LICENSE)),
so the image's `org.opencontainers.image.licenses` label is set to the license of the
software it redistributes instead: **GPL-3.0-only** for the bundled upstream
[truenas-mcp](https://github.com/truenas/truenas-mcp) binary. `supergateway` is MIT.
Review the upstream licenses before redistributing.