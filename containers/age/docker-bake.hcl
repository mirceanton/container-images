DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-tags depName=FiloSottile/age
    default = "1.1.1"
}

target "default" {
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { AGE_VERSION = VERSION }

    tags = [
        "ghcr.io/mirceanton/age:latest",
        "ghcr.io/mirceanton/age:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/age:date-${DATE}",
        "ghcr.io/mirceanton/age:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/age:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/age:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "age"
        "org.opencontainers.image.authors" = "Filippo Valsorda"
        "org.opencontainers.image.description" = "Modern encryption tool age in a container"
        "org.opencontainers.image.url" = "https://github.com/FiloSottile/age"
        "org.opencontainers.image.version" = "${VERSION}"
    }
}