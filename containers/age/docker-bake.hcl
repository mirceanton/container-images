DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-tags depName=FiloSottile/age
    default = "1.1.1"
}

target "default" {
    matrix = {
        binary = ["age", "age-keygen"]
    }
    name = "${binary}"
    context = "."
    dockerfile = "Dockerfile"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = { 
        AGE_VERSION = VERSION
        BINARY = binary
    }

    tags = [
        "ghcr.io/mirceanton/${binary}:latest",
        "ghcr.io/mirceanton/${binary}:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/${binary}:date-${DATE}",
        "ghcr.io/mirceanton/${binary}:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/${binary}:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/${binary}:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "${binary}"
        "org.opencontainers.image.authors" = "Filippo Valsorda"
        "org.opencontainers.image.description" = "Modern encryption tool age in a container"
        "org.opencontainers.image.url" = "https://github.com/FiloSottile/age"
        "org.opencontainers.image.version" = "${VERSION}"
    }
}