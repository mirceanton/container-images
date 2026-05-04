# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM golang:1.24-alpine3.21 AS builder
ARG ZFS_EXPORTER_VERSION
ARG TARGETARCH

# hadolint ignore=DL3018
RUN apk add --no-cache gcc musl-dev zfs-dev git && \
    go install github.com/pdf/zfs_exporter/v2@v${ZFS_EXPORTER_VERSION}

# ===============================================================================
# Final image
# ===============================================================================
FROM alpine:3.23

# hadolint ignore=DL3018
RUN apk add --no-cache zfs

COPY --from=builder /go/bin/zfs_exporter /usr/local/bin/zfs_exporter

EXPOSE 9134
ENTRYPOINT ["/usr/local/bin/zfs_exporter"]
