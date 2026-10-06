# syntax=docker/dockerfile:1

# ===============================================================================
# Downloader stage
# ===============================================================================
FROM alpine:3.24 AS downloader
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
ARG TRUENAS_MCP_VERSION
WORKDIR /tmp

RUN echo "Downloading truenas-mcp version ${TRUENAS_MCP_VERSION} for linux/amd64"

# hadolint ignore=DL3018
RUN apk add --no-cache curl tar && \
    release="https://github.com/truenas/truenas-mcp/releases/download/v${TRUENAS_MCP_VERSION}" && \
    curl -fsSL -o truenas-mcp-linux-amd64.tar.gz "${release}/truenas-mcp-linux-amd64.tar.gz" && \
    curl -fsSL -o checksums.txt "${release}/checksums.txt" && \
    grep " truenas-mcp-linux-amd64.tar.gz$" checksums.txt | sha256sum -c - && \
    tar -xzf truenas-mcp-linux-amd64.tar.gz -C /usr/local/bin truenas-mcp-linux-amd64 && \
    mv /usr/local/bin/truenas-mcp-linux-amd64 /usr/local/bin/truenas-mcp && \
    chmod +x /usr/local/bin/truenas-mcp

# ===============================================================================
# Final image
#
# The upstream binary is a cgo build linked against glibc (PT_INTERP
# /lib64/ld-linux-x86-64.so.2, DT_NEEDED libc.so.6), so it cannot run on the
# musl-based supergateway image (node:*-alpine -> /lib/ld-musl-x86_64.so.1, no
# glibc loader and no gcompat). This image therefore uses a glibc base with the
# same Node major as upstream's bridge image (node:20-alpine) and installs
# supergateway from npm with the same flags its Dockerfile uses.
# ===============================================================================
FROM node:20-bookworm-slim

ARG SUPERGATEWAY_VERSION

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g supergateway@${SUPERGATEWAY_VERSION} \
        --omit=dev --ignore-scripts --engine-strict --no-audit --no-fund && \
    npm cache clean --force

COPY --from=downloader /usr/local/bin/truenas-mcp /usr/local/bin/truenas-mcp

EXPOSE 8080

ENTRYPOINT [ "supergateway" ]
CMD [ \
    "--stdio", "truenas-mcp", \
    "--outputTransport", "streamableHttp", \
    "--port", "8080", \
    "--streamableHttpPath", "/mcp", \
    "--healthEndpoint", "/healthz" \
]