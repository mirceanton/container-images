# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM alpine:3.23 AS downloader
ARG AGE_VERSION
ARG TARGETARCH

RUN echo "Downloading age version ${AGE_VERSION} for architecture ${TARGETARCH}"
RUN apk add --no-cache curl tar && \
    curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-${TARGETARCH}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/age/age /usr/local/bin/age && \
    mv /tmp/age/age-keygen /usr/local/bin/age-keygen && \
    chmod +x /usr/local/bin/age*

# ===============================================================================
# Final image
# ===============================================================================
# trivy:ignore:DS002
FROM alpine:3.23
RUN apk add --no-cache bash git
COPY --from=downloader /usr/local/bin/age /usr/local/bin/age
COPY --from=downloader /usr/local/bin/age-keygen /usr/local/bin/age-keygen
ENTRYPOINT ["/bin/sh"]
CMD ["-c", "age --version"]