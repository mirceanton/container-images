# syntax=docker/dockerfile:1

# ===============================================================================
# Builder stage
# ===============================================================================
FROM golang:1.24-alpine3.21 AS builder
ARG ZFS_EXPORTER_VERSION
ARG TARGETARCH

RUN apk add --no-cache gcc musl-dev zfs-dev git

RUN go install github.com/pdf/zfs_exporter/v2@v${ZFS_EXPORTER_VERSION}

# ===============================================================================
# Final image
# ===============================================================================
FROM alpine:3.21
# zfs package provides the zfs/zpool CLI tools that the exporter calls at runtime.
# Alpine 3.21 ships ZFS 2.2.7, which is compatible with OpenZFS 2.4.x kernel modules.
RUN apk add --no-cache zfs

COPY --from=builder /go/bin/zfs_exporter /usr/local/bin/zfs_exporter

EXPOSE 9134
ENTRYPOINT ["/usr/local/bin/zfs_exporter"]
