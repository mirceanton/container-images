# syntax=docker/dockerfile:1

ARG RUNNER_VERSION
FROM ghcr.io/actions/actions-runner:${RUNNER_VERSION}

ARG RENOVATE_VERSION

# Switch to root to install packages
USER root

# Install Node.js (required for Renovate) and other dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        gnupg \
        ca-certificates \
        git \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Renovate globally
RUN npm install -g renovate@${RENOVATE_VERSION} \
    && npm cache clean --force

# Verify installations
RUN node --version && npm --version && renovate --version

# Switch back to the runner user
USER runner

# Set Renovate-specific environment variables
ENV RENOVATE_BINARY_SOURCE=global

ENTRYPOINT ["/home/runner/run.sh"]
