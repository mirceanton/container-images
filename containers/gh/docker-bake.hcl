DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-tags depName=cli/cli
    default = "2.83.1"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { GH_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/gh:latest",
        "ghcr.io/mirceanton/gh:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/gh:date-${DATE}",
        "ghcr.io/mirceanton/gh:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/gh:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/gh:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "GitHub CLI"
        "org.opencontainers.image.authors" = "GitHub CLI Team"
        "org.opencontainers.image.description" = "GitHub CLI in a container"
        "org.opencontainers.image.url" = "https://github.com/cli/cli"
        "org.opencontainers.image.version" = "${VERSION}"
    }
}