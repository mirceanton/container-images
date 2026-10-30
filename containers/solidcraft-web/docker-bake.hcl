DATE = formatdate("YYYY.MM.DD", timestamp())
variable "GIT_SHA" {}
variable "SOLIDCRAFT_VERSION" {
    # renovate: datasource=github-releases depName=tangency-labs/solidcraft
    default = "0.25.0"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { SOLIDCRAFT_VERSION = SOLIDCRAFT_VERSION }

    tags = [
        "ghcr.io/mirceanton/solidcraft-web:latest",
        "ghcr.io/mirceanton/solidcraft-web:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/solidcraft-web:date-${DATE}",
        "ghcr.io/mirceanton/solidcraft-web:${SOLIDCRAFT_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", SOLIDCRAFT_VERSION)) ? "ghcr.io/mirceanton/solidcraft-web:${regex("^([0-9]+\\.[0-9]+)", SOLIDCRAFT_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", SOLIDCRAFT_VERSION)) ? "ghcr.io/mirceanton/solidcraft-web:${regex("^([0-9]+)", SOLIDCRAFT_VERSION)[0]}" : ""
    ]

    annotations = [
        "index:org.opencontainers.image.visibility=public",
        "index:org.opencontainers.image.source=https://github.com/mirceanton/container-images",
        "index:org.opencontainers.image.description=SolidCraft web app, served via nginx on port 8080. Upstream: https://solidcraft.io",
        "index:org.opencontainers.image.version=${SOLIDCRAFT_VERSION}",
        "index:org.opencontainers.image.licenses=MIT OR Apache-2.0",
        "index:org.opencontainers.image.url=https://solidcraft.io",
        "index:org.opencontainers.image.documentation=https://docs.solidcraft.io",
        "index:org.opencontainers.image.title=SolidCraft",
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"
        "org.opencontainers.image.title" = "SolidCraft"
        "org.opencontainers.image.authors" = "Tangency Labs"
        "org.opencontainers.image.description" = "SolidCraft web app, served via nginx on port 8080"
        "org.opencontainers.image.url" = "https://solidcraft.io"
        "org.opencontainers.image.version" = "${SOLIDCRAFT_VERSION}"
    }
}