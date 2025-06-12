# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM alpine:3.22 AS downloader
ARG AGE_VERSION
ARG TARGETARCH
ARG BINARY

RUN echo "Downloading age version ${AGE_VERSION} for architecture ${TARGETARCH}"
RUN apk add --no-cache curl tar && \
    curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-${TARGETARCH}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/age/${BINARY} /usr/local/bin/${BINARY} && \
    chmod +x /usr/local/bin/${BINARY}

# ===============================================================================
# Final image
# ===============================================================================
FROM alpine:3.22
ARG BINARY
RUN apk add --no-cache bash
COPY --from=downloader /usr/local/bin/${BINARY} /usr/local/bin/${BINARY}
ENTRYPOINT ["/bin/bash"]