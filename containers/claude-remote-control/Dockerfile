# syntax=docker/dockerfile:1
ARG MISE_VERSION
ARG CLAUDE_CODE_VERSION

# ===============================================================================
# Source stage — pull the mise binary from the official mise image
# ===============================================================================
FROM ghcr.io/jdx/mise:${MISE_VERSION} AS mise-source

# ===============================================================================
# Install stage — use mise to bootstrap Node, then npm-install the Claude CLI
# ===============================================================================
FROM debian:13-slim AS install
ARG CLAUDE_CODE_VERSION

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends ca-certificates curl git build-essential && \
    rm -rf /var/lib/apt/lists/*
COPY --from=mise-source /usr/local/bin/mise /usr/local/bin/mise

ENV MISE_DATA_DIR="/home/claude/.mise/data"
ENV MISE_CACHE_DIR="/home/claude/.mise/cache"
ENV MISE_CONFIG_DIR="/home/claude/.config/mise"
ENV MISE_TRUSTED_CONFIG_PATHS="/home/claude"
ENV MISE_YES="1"
ENV PATH="${MISE_DATA_DIR}/shims:${PATH}"

COPY mise.toml "${MISE_CONFIG_DIR}/config.toml"
RUN mise install

# Copy the resolved node install out to a fixed, mise-independent path.
# MISE_DATA_DIR here is scratch: at runtime it's replaced by an (initially
# empty) PVC for per-repo tool caching, so the node claude itself needs to
# run can't live inside it -- it would be shadowed the moment that volume
# mounts. /opt/node is never touched by a volume mount.
RUN mkdir -p /opt/node && cp -a "$(mise where node)/." /opt/node/
ENV PATH="/opt/node/bin:${PATH}"

# Fixed, node-version-independent location for the claude-code package,
# so the runtime stage doesn't need to know which node patch built it.
ENV npm_config_prefix="/home/claude/.npm-global"
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" && \
    npm cache clean --force

# ===============================================================================
# Final image
# ===============================================================================
FROM debian:13-slim

# hadolint ignore=DL3008
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl git openssh-client unzip procps && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid 1000 claude && \
    useradd --uid 1000 --gid claude --shell /bin/bash --create-home claude

# /opt/node and mise itself are fixed, image-owned paths -- nothing mounts
# over them. /home/claude/.mise (mise's live data/cache dir, PVC-backed at
# deploy time) intentionally starts empty; it's for tools *other* repos pin
# in their own mise.toml, resolved on demand, not for anything this image
# bakes in.
COPY --from=mise-source /usr/local/bin/mise /usr/local/bin/mise
COPY --from=install /opt/node /opt/node
COPY --from=install --chown=claude:claude /home/claude/.npm-global /home/claude/.npm-global
COPY --chown=claude:claude mise.toml /home/claude/.config/mise/config.toml
COPY --chmod=0755 files/entrypoint.sh /usr/local/bin/entrypoint.sh

ENV HOME="/home/claude"
ENV MISE_DATA_DIR="/home/claude/.mise/data"
ENV MISE_CACHE_DIR="/home/claude/.mise/cache"
ENV MISE_CONFIG_DIR="/home/claude/.config/mise"
# Auto-trust mise.toml found anywhere under $HOME (cloned repos live under
# $HOME/workspace) so the agent never has to run `mise trust` by hand.
ENV MISE_TRUSTED_CONFIG_PATHS="/home/claude"
# Auto-confirm tool installs mise finds pinned in a repo's own mise.toml.
ENV MISE_YES="1"
ENV PATH="/home/claude/.npm-global/bin:/opt/node/bin:/home/claude/.mise/data/shims:${PATH}"

# Never set here: ANTHROPIC_BASE_URL or any other LLM-gateway/provider-routing
# env var. This image must only ever talk to api.anthropic.com directly --
# setting any of those breaks Remote Control outright (see README.md).

RUN mkdir -p /home/claude/workspace && chown claude:claude /home/claude/workspace

USER claude
WORKDIR /home/claude/workspace

# No inbound port: `claude remote-control` only makes outbound HTTPS calls to
# api.anthropic.com, so liveness is "is the process still running", not an
# HTTP endpoint. See README.md for the Kubernetes exec-probe equivalent.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD pgrep -f "remote-control" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["--spawn=same-dir"]
