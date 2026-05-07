DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}

variable "NAVIDROME_MCP_VERSION" {
    # renovate: datasource=npm depName=navidrome-mcp
    default = "1.1.2"
}

variable "SUPERGATEWAY_VERSION" {
    # renovate: datasource=npm depName=supergateway
    default = "3.4.3"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64", "linux/arm64"]
    args = {
        NAVIDROME_MCP_VERSION = NAVIDROME_MCP_VERSION
        SUPERGATEWAY_VERSION  = SUPERGATEWAY_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/navidrome-mcp:latest",
        "ghcr.io/mirceanton/navidrome-mcp:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/navidrome-mcp:date-${DATE}",
        "ghcr.io/mirceanton/navidrome-mcp:${NAVIDROME_MCP_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", NAVIDROME_MCP_VERSION)) ? "ghcr.io/mirceanton/navidrome-mcp:${regex("^([0-9]+\\.[0-9]+)", NAVIDROME_MCP_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", NAVIDROME_MCP_VERSION)) ? "ghcr.io/mirceanton/navidrome-mcp:${regex("^([0-9]+)", NAVIDROME_MCP_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "AGPL-3.0"

        "org.opencontainers.image.title"       = "navidrome-mcp"
        "org.opencontainers.image.authors"     = "Blakeem"
        "org.opencontainers.image.description" = "navidrome-mcp MCP server exposed over Streamable HTTP via supergateway"
        "org.opencontainers.image.url"         = "https://github.com/Blakeem/Navidrome-MCP"
        "org.opencontainers.image.version"     = "${NAVIDROME_MCP_VERSION}"
    }
}

