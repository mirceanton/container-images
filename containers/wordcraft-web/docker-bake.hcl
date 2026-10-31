DATE = formatdate("YYYY.MM.DD", timestamp())
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-releases depName=storytold/wordcraft
    default = "0.12.0"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/wordcraft-web:latest",
        "ghcr.io/mirceanton/wordcraft-web:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/wordcraft-web:date-${DATE}",
        "ghcr.io/mirceanton/wordcraft-web:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/wordcraft-web:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/wordcraft-web:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"
        "org.opencontainers.image.title"       = "WordCraft"
        "org.opencontainers.image.authors"     = "ArtCraft (storytold)"
        "org.opencontainers.image.description" = "WordCraft web app, served via nginx on port 8080"
        "org.opencontainers.image.url"         = "https://getartcraft.com/apps/wordcraft"
        "org.opencontainers.image.version"     = "${VERSION}"
    }

    annotations = [
        "index:org.opencontainers.image.visibility=public",
        "index:org.opencontainers.image.source=https://github.com/mirceanton/container-images",
        "index:org.opencontainers.image.description=WordCraft web app, served via nginx on port 8080. Upstream: https://getartcraft.com/apps/wordcraft",
        "index:org.opencontainers.image.version=${VERSION}",
        "index:org.opencontainers.image.licenses=MIT OR Apache-2.0",
        "index:org.opencontainers.image.url=https://getartcraft.com/apps/wordcraft",
        "index:org.opencontainers.image.documentation=https://github.com/storytold/wordcraft",
        "index:org.opencontainers.image.title=WordCraft",
    ]
}