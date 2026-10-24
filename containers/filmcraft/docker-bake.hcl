DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-tags depName=storytold/filmcraft
    default = "0.12.0"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { FILMCRAFT_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/filmcraft:latest",
        "ghcr.io/mirceanton/filmcraft:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/flmcraft:date-${DATE}",
        "ghcr.io/mirceanton/filmcraft:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/filmcraft:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/filmcraft:${regex("^([0-9]+)", VERSION)[0]}" : "",
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "FilmCraft"
        "org.opencontainers.image.authors" = "FilmCraft Team"
        "org.opencontainers.image.description" = "Open-source professional NLE with headless CLI and MCP server, in a container"
        "org.opencontainers.image.url" = "https://github.com/storytold/filmcraft"
        "org.opencontainers.image. leadership"
    }
}
