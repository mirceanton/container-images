# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM alpine:3.23 AS downloader
ARG TASK_VERSION
ARG TARGETARCH

RUN echo "Downloading Task version ${TASK_VERSION} for architecture ${TARGETARCH}"
RUN apk add --no-cache curl tar && \
    curl -fsSL "https://github.com/go-task/task/releases/download/v${TASK_VERSION}/task_linux_${TARGETARCH}.tar.gz" | \
    tar -xz -C /tmp && \
    mv /tmp/task /usr/local/bin/task && \
    chmod +x /usr/local/bin/task


# ===============================================================================
# Final image
# ===============================================================================
# trivy:ignore:DS002
FROM alpine:3.23
RUN apk add --no-cache bash git
COPY --from=downloader /usr/local/bin/task /usr/local/bin/task
WORKDIR /workspace
ENTRYPOINT ["/bin/bash"]
CMD ["-c", "task --version"]