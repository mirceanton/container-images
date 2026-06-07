DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "UBUNTU_VERSION" {
    # renovate: datasource=docker depName=ghcr.io/selkies-project/nvidia-glx-desktop
    default = "24.04"
}
variable "SUNSHINE_VERSION" {
    # renovate: datasource=github-releases depName=LizardByte/Sunshine extractVersion=^v(?<version>.+)$
    default = "2026.516.143833"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = false
    platforms  = ["linux/amd64"]
    args = {
        UBUNTU_VERSION   = UBUNTU_VERSION
        SUNSHINE_VERSION = SUNSHINE_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/selkies-gaming:latest",
        "ghcr.io/mirceanton/selkies-gaming:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/selkies-gaming:date-${DATE}",
        "ghcr.io/mirceanton/selkies-gaming:${UBUNTU_VERSION}",
        "ghcr.io/mirceanton/selkies-gaming:${UBUNTU_VERSION}-sunshine-${SUNSHINE_VERSION}",
    ]

    labels = {
        "org.opencontainers.image.vendor"   = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"   = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"  = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title"       = "Selkies Gaming Desktop"
        "org.opencontainers.image.authors"     = "selkies-project, LizardByte"
        "org.opencontainers.image.description" = "NVIDIA-accelerated Ubuntu desktop with WebRTC streaming (Selkies), Moonlight streaming (Sunshine), and Steam"
        "org.opencontainers.image.url"         = "https://github.com/selkies-project/docker-selkies-glx-desktop"
        "org.opencontainers.image.version"     = "${UBUNTU_VERSION}-sunshine-${SUNSHINE_VERSION}"
    }
}
