DATE = formatdate( "YYYY.MM.DD", timestamp() )
variable "GIT_SHA" {}

variable "MISE_VERSION" {
    # renovate: datasource=docker depName=ghcr.io/jdx/mise
    default = "2026.5"
}
variable "NODE_MAJOR" {
    # renovate: datasource=node-version depName=node
    default = "24"
}
variable "CLAUDE_CODE_VERSION" {
    # renovate: datasource=npm depName=@anthropic-ai/claude-code
    default = "2.1.257"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64", "linux/arm64"]
    args = {
        MISE_VERSION        = MISE_VERSION
        NODE_MAJOR          = NODE_MAJOR
        CLAUDE_CODE_VERSION = CLAUDE_CODE_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/claude-remote-control:latest",
        "ghcr.io/mirceanton/claude-remote-control:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/claude-remote-control:date-${DATE}",
        "ghcr.io/mirceanton/claude-remote-control:${CLAUDE_CODE_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", CLAUDE_CODE_VERSION)) ? "ghcr.io/mirceanton/claude-remote-control:${regex("^([0-9]+\\.[0-9]+)", CLAUDE_CODE_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", CLAUDE_CODE_VERSION)) ? "ghcr.io/mirceanton/claude-remote-control:${regex("^([0-9]+)", CLAUDE_CODE_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "SEE LICENSE IN https://github.com/anthropics/claude-code/blob/main/LICENSE.md"

        "org.opencontainers.image.title"       = "claude-remote-control"
        "org.opencontainers.image.authors"     = "Anthropic"
        "org.opencontainers.image.description" = "Claude Code running `claude remote-control` as an always-on server, with mise kept live only for per-repo tool resolution"
        "org.opencontainers.image.url"         = "https://github.com/anthropics/claude-code"
        "org.opencontainers.image.version"     = "${CLAUDE_CODE_VERSION}"
    }
}
