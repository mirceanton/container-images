DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-releases depName=pdf/zfs_exporter
    default = "2.3.11"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64", "linux/arm64"]
    args       = { ZFS_EXPORTER_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/zfs-exporter:latest",
        "ghcr.io/mirceanton/zfs-exporter:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/zfs-exporter:date-${DATE}",
        "ghcr.io/mirceanton/zfs-exporter:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/zfs-exporter:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/zfs-exporter:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "zfs-exporter"
        "org.opencontainers.image.authors"     = "pdf"
        "org.opencontainers.image.description" = "Prometheus exporter for ZFS pools, datasets, and snapshots"
        "org.opencontainers.image.url"         = "https://github.com/pdf/zfs_exporter"
        "org.opencontainers.image.version"     = "${VERSION}"
    }
}
