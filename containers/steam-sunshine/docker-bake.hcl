DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "UBUNTU_VERSION" {
    # renovate: datasource=docker depName=ubuntu
    default = "26.04"
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
        "ghcr.io/mirceanton/steam-sunshine:latest",
        "ghcr.io/mirceanton/steam-sunshine:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/steam-sunshine:date-${DATE}",
        "ghcr.io/mirceanton/steam-sunshine:${UBUNTU_VERSION}",
        "ghcr.io/mirceanton/steam-sunshine:${UBUNTU_VERSION}-sunshine-${SUNSHINE_VERSION}",
    ]

    labels = {
        "org.opencontainers.image.vendor"   = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"   = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"  = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title"       = "Steam + Sunshine"
        "org.opencontainers.image.authors"     = "selkies-project, LizardByte"
        "org.opencontainers.image.description" = "Lean NVIDIA-accelerated Ubuntu image with Steam and Sunshine (Moonlight) for couch/controller game streaming"
        "org.opencontainers.image.url"         = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.version"     = "${UBUNTU_VERSION}-sunshine-${SUNSHINE_VERSION}"
    }
}
