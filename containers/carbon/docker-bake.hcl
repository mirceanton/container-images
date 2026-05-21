DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}

variable "CARBON_VERSION" {
    # renovate: datasource=github-tags depName=carbon-app/carbon
    default = "4.9.10"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64", "linux/arm64"]
    args = {
        CARBON_VERSION = CARBON_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/carbon:latest",
        "ghcr.io/mirceanton/carbon:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/carbon:date-${DATE}",
        "ghcr.io/mirceanton/carbon:${CARBON_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", CARBON_VERSION)) ? "ghcr.io/mirceanton/carbon:${regex("^([0-9]+\\.[0-9]+)", CARBON_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", CARBON_VERSION)) ? "ghcr.io/mirceanton/carbon:${regex("^([0-9]+)", CARBON_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "Carbon"
        "org.opencontainers.image.authors"     = "carbon-app"
        "org.opencontainers.image.description" = "Create and share beautiful images of your source code"
        "org.opencontainers.image.url"         = "https://github.com/carbon-app/carbon"
        "org.opencontainers.image.version"     = "${CARBON_VERSION}"
    }
}
