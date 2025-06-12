# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM alpine:3.22 AS downloader
ARG GH_VERSION
ARG TARGETARCH

RUN echo "Downloading GitHub CLI version ${GH_VERSION} for architecture ${TARGETARCH}"
RUN apk add --no-cache curl tar && \
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" | \
    tar -xz --strip-components=1 -C /tmp && \
    mv /tmp/bin/gh /usr/local/bin/gh && \
    chmod +x /usr/local/bin/gh


# ===============================================================================
# Final image
# ===============================================================================
FROM alpine:3.22
RUN apk add --no-cache git openssh-client
COPY --from=downloader /usr/local/bin/gh /usr/local/bin/gh
ENTRYPOINT ["/bin/bash"]
CMD ["-c", "gh --version"]