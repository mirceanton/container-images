# syntax=docker/dockerfile:1
ARG MISE_VERSION
ARG NODE_MAJOR
ARG CLAUDE_CODE_VERSION

# ===============================================================================
# Source stage — pull the mise binary from the official mise image
# ===============================================================================
FROM ghcr.io/jdx/mise:${MISE_VERSION} AS mise-source

# ===============================================================================
# Final image
# ===============================================================================
FROM debian:13-slim
ARG NODE_MAJOR
ARG CLAUDE_CODE_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg git openssh-client unzip procps && \
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid 1000 claude && \
    useradd --uid 1000 --gid claude --shell /bin/bash --create-home claude

COPY --from=mise-source /usr/local/bin/mise /usr/local/bin/mise

RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" && \
    npm cache clean --force

COPY --chmod=0755 files/entrypoint.sh /usr/local/bin/entrypoint.sh

ENV HOME="/home/claude"
ENV MISE_DATA_DIR="/home/claude/.mise/data"
ENV MISE_CACHE_DIR="/home/claude/.mise/cache"
ENV MISE_TRUSTED_CONFIG_PATHS="/home/claude"
ENV MISE_YES="1"
ENV PATH="/home/claude/.mise/data/shims:${PATH}"

# Never set here: ANTHROPIC_BASE_URL or any other LLM-gateway/provider-routing
# env var -- this image must only ever talk to api.anthropic.com directly.

RUN mkdir -p /home/claude/workspace && chown claude:claude /home/claude/workspace

USER claude
WORKDIR /home/claude/workspace

# No inbound port: Remote Control is outbound-only, so liveness is "process
# still running", not an HTTP endpoint. K8s exec-probe equivalent in README.md.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD pgrep -f "remote-control" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--spawn=same-dir"]
