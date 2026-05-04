# syntax=docker/dockerfile:1
ARG MISE_VERSION
ARG ACTIONS_RUNNER_VERSION

# ===============================================================================
# Source stage — pull the mise binary from the official mise image
# ===============================================================================
FROM ghcr.io/jdx/mise:${MISE_VERSION} AS mise-source

# ===============================================================================
# Final image
# ===============================================================================
FROM ghcr.io/actions/actions-runner:${ACTIONS_RUNNER_VERSION}

USER root
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
COPY --from=mise-source /usr/local/bin/mise /usr/local/bin/mise
RUN mkdir -p /opt/mise /cache/mise && chown runner:runner /opt/mise /cache/mise

USER runner
ENV MISE_DATA_DIR="/opt/mise"
ENV MISE_CACHE_DIR="/cache/mise"
ENV MISE_YES="1"
ENV PATH="/opt/mise/shims:$PATH"
RUN echo 'eval "$(mise activate bash)"' >> "${HOME}/.bashrc"

ENTRYPOINT ["/bin/bash"]
CMD ["-c", "mise --version"]
