DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]

    tags = [
        "ghcr.io/mirceanton/truenas-backup:latest",
        "ghcr.io/mirceanton/truenas-backup:${DATE}",
        "ghcr.io/mirceanton/truenas-backup:sha-${GIT_SHA}",
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "TrueNAS Backup"
        "org.opencontainers.image.authors" = "Mircea-Pavel Anton"
        "org.opencontainers.image.description" = "Automated TrueNAS configuration backup to S3-compatible storage"
    }
}
