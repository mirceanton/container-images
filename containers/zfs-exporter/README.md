# zfs-exporter Container Image

Container image for [zfs_exporter](https://github.com/pdf/zfs_exporter), a Prometheus exporter for ZFS that provides pool health, dataset capacity, and snapshot metrics.

## Why a custom image?

`pdf/zfs_exporter` does not publish an official container image, only binary releases for non-Linux platforms. This image builds the exporter from source against Alpine's ZFS libraries.

## Usage

```bash
docker pull ghcr.io/mirceanton/zfs-exporter:latest
```

```bash
docker run --rm \
  --privileged \
  -p 9134:9134 \
  ghcr.io/mirceanton/zfs-exporter:latest
```

Metrics are exposed on port `9134` at `/metrics`.

## Alpine / ZFS version pairing

The image is built on **Alpine 3.21**, which ships ZFS **2.3.x**. The `zfs-libs` package provides only the shared `libzfs.so` runtime without the full `zfs`/`zpool` CLI tools, keeping the image minimal.

Alpine 3.21's ZFS 2.3.x userspace ABI is backward-compatible with ZFS kernel module 2.4.x via the ioctl interface, making it safe to run against a Talos node running the ZFS 2.4.0 extension.
