DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}
variable "VERSION" {
    # renovate: datasource=github-releases depName=truenas/truenas-mcp
    default = "0.0.6"
}
variable "SUPERGATEWAY_VERSION" {
    # renovate: datasource=npm depName=supergateway
    default = "4.1.0"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    # The upstream release only ships a linux-amd64 binary (make build-all), so
    # unlike the other images here this one is amd64-only.
    platforms  = ["linux/amd64"]
    args       = { TRUENAS_MCP_VERSION = VERSION, SUPERGATEWAY_VERSION = SUPERGATEWAY_VERSION }

    tags = [
        "ghcr.io/mirceanton/truenas-mcp:latest",
        "ghcr.io/mirceanton/truenas-mcp:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/truenas-mcp:date-${DATE}",
        "ghcr.io/mirceanton/truenas-mcp:${VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/truenas-mcp:${regex("^([0-9]+\\.[0-9]+)", VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", VERSION)) ? "ghcr.io/mirceanton/truenas-mcp:${regex("^([0-9]+)", VERSION)[0]}" : ""
    ]

    # the image redistributes iXsystems' GPL-3.0 binary; the Dockerfile and repo
    # tooling around it are MIT, which is why the license label is not the repo's
    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "GPL-3.0-only"

        "org.opencontainers.image.title"       = "truenas-mcp"
        "org.opencontainers.image.authors"     = "iXsystems (TrueNAS MCP), Supercorp (supergateway)"
        "org.opencontainers.image.description" = "TrueNAS MCP stdio server exposed over Streamable HTTP by supergateway"
        "org.opencontainers.image.url"         = "https://github.com/truenas/truenas-mcp"
        "org.opencontainers.image.version"     = "${VERSION}"
    }
}