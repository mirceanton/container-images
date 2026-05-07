# syntax=docker/dockerfile:1

# ===============================================================================
# Final image
# ===============================================================================
FROM node:22-alpine

ARG NAVIDROME_MCP_VERSION
ARG SUPERGATEWAY_VERSION

# hadolint ignore=DL3018
RUN apk add --no-cache dumb-init

RUN npm install -g \
    navidrome-mcp@${NAVIDROME_MCP_VERSION} \
    supergateway@${SUPERGATEWAY_VERSION} \
    && npm cache clean --force

EXPOSE 3000

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["npx", "supergateway", \
    "--stdio", "navidrome-mcp", \
    "--outputTransport", "streamable-http", \
    "--port", "3000", \
    "--httpPath", "/mcp", \
    "--healthEndpoint", "/healthz"]

