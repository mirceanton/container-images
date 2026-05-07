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

### Environment Configuration

The container runs supergateway with navidrome-mcp as the MCP server. You can override the default command to configure:

```bash
docker run --rm -p 3000:8080 ghcr.io/mirceanton/navidrome-mcp:latest \
  npx supergateway \
    --stdio navidrome-mcp \
    --outputTransport streamable-http \
    --port 8080 \
    --httpPath /mcp \
    --healthEndpoint /healthz
```

## Included Tools

- `navidrome-mcp` - MCP server for Navidrome
- `supergateway` - HTTP transport for MCP servers
- `node` - JavaScript runtime
