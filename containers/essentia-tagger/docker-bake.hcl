DATE = formatdate("YYYY.MM.DD", timestamp())
variable "GIT_SHA" {}

variable "ESSENTIA_TAGGER_REV" {
    # renovate: datasource=git-refs depName=WB2024/Essentia-to-Metadata
    # Pinned to the latest commit on main (Apr 4, 2026)
    default = "fe6b0946cdf547dd3281af10459e6cccc5d254fd"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64"]
    args = {
        ESSENTIA_TAGGER_REV = ESSENTIA_TAGGER_REV
    }

    tags = [
        "ghcr.io/mirceanton/essentia-tagger:latest",
        "ghcr.io/mirceanton/essentia-tagger:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/essentia-tagger:date-${DATE}",
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "Essentia Music Tagger"
        "org.opencontainers.image.authors"     = "WB2024"
        "org.opencontainers.image.description" = "Intelligent audio analysis and automatic genre/mood tagging using Essentia ML models"
        "org.opencontainers.image.url"         = "https://github.com/WB2024/Essentia-to-Metadata"
        "org.opencontainers.image.version"     = "${ESSENTIA_TAGGER_REV}"
    }
}
