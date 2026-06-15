# Navidrome MCP Container Image

Container image for [navidrome-mcp](https://github.com/Blakeem/Navidrome-MCP), an MCP (Model Context Protocol) server for Navidrome that exposes it over HTTP via [supergateway](https://github.com/statechangelabs/supergateway).

## Usage

```bash
docker pull ghcr.io/mirceanton/navidrome-mcp:latest
```

### Basic Usage

```bash
docker run --rm -p 3000:3000 ghcr.io/mirceanton/navidrome-mcp:latest
```

The server will be available at `http://localhost:3000/mcp` with health checks at `/healthz`.

### Configuration

> [!IMPORTANT]
> Since v2.0.0, `navidrome-mcp` reads configuration exclusively from a `settings.json` file.
> Environment variables (`NAVIDROME_URL`, `NAVIDROME_USERNAME`, `NAVIDROME_PASSWORD`, etc.) are **not supported** and are silently ignored.
> Without a valid `settings.json`, the server starts in setup mode — it opens a local HTTP server waiting for browser-based configuration and **never exits**, causing zombie process accumulation and OOM in containerised deployments.

Mount a `settings.json` file and point `NAVIDROME_CONFIG_PATH` at it:

```json
{
  "navidrome": {
    "url": "http://navidrome:4533",
    "username": "your-username",
    "password": "your-password"
  },
  "webui": {
    "enabled": false
  }
}
```

```bash
docker run --rm -p 3000:3000 \
  -v /path/to/settings.json:/config/settings.json:ro \
  -e NAVIDROME_CONFIG_PATH=/config/settings.json \
  ghcr.io/mirceanton/navidrome-mcp:latest
```

Setting `webui.enabled: false` prevents the web UI server from keeping the process alive after each stateless MCP session ends.

### Supergateway Options

To override the supergateway defaults (port, path, etc.):

```bash
docker run --rm -p 8080:8080 \
  -v /path/to/settings.json:/config/settings.json:ro \
  -e NAVIDROME_CONFIG_PATH=/config/settings.json \
  ghcr.io/mirceanton/navidrome-mcp:latest \
  npx supergateway \
    --stdio navidrome-mcp \
    --outputTransport streamableHttp \
    --port 8080 \
    --httpPath /mcp \
    --healthEndpoint /healthz
```

## Included Tools

- `navidrome-mcp` - MCP server for Navidrome
- `supergateway` - HTTP transport for MCP servers
- `node` - JavaScript runtime
