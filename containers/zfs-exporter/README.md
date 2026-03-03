# zfs-exporter Container Image

Container image for [zfs_exporter](https://github.com/pdf/zfs_exporter), a Prometheus exporter for ZFS that provides pool health, dataset capacity, and snapshot metrics.

## Why a custom image?

`pdf/zfs_exporter` does not publish an official container image, only binary releases. This image builds the exporter from source against Alpine's ZFS libraries.

## Usage (Docker)

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

## Usage (Kubernetes)

I use the bjw-s-labs/app-template helm chart to easily set up this exporter with the following values file on my Talos node:

```yaml
controllers:
  zfs-exporter:
    containers:
      zfs-exporter:
        image:
          repository: ghcr.io/mirceanton/zfs-exporter
          tag: latest #! replace with a specific version

        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            memory: 64Mi

        #? Needs privileged access to /dev/zfs to query pool/dataset state via libzfs ioctls.
        #? On Talos, ZFS is loaded as a kernel extension so /dev/zfs is available on the host.
        securityContext:
          privileged: true

defaultPodOptions:
  securityContext:
    runAsUser: 0
    runAsGroup: 0

service:
  zfs-exporter:
    ports:
      http:
        port: 9134

serviceMonitor:
  zfs-exporter:
    serviceName: zfs-exporter
    endpoints:
      - port: http
        scheme: http
        path: /metrics
        interval: 1m
        scrapeTimeout: 30s

persistence:
  dev-zfs:
    type: hostPath
    hostPath: /dev/zfs
    globalMounts:
      - path: /dev/zfs
```

Or, more specifically if using FluxCD:

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: zfs-exporter
spec:
  interval: 15m
  url: oci://ghcr.io/bjw-s-labs/helm/app-template
  ref: {tag: 4.6.2}

  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy

---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: zfs-exporter
spec:
  interval: 10m
  chartRef:
    kind: OCIRepository
    name: zfs-exporter

  # use values from above
  values: {}
```
