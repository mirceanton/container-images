DATE = formatdate("YYYY.MM.DD", timestamp())
variable "GIT_SHA" {}

variable "BEETS_VERSION" {
    # renovate: datasource=pypi depName=beets
    default = "2.3.1"
}

variable "MUTAGEN_VERSION" {
    # renovate: datasource=pypi depName=mutagen
    default = "1.47.0"
}

variable "PYYAML_VERSION" {
    # renovate: datasource=pypi depName=pyyaml
    default = "6.0.3"
}

variable "REQUESTS_VERSION" {
    # renovate: datasource=pypi depName=requests
    default = "2.32.5"
}

variable "LAP_VERSION" {
    # renovate: datasource=pypi depName=lap
    default = "0.4.0"
}

target "default" {
    context    = "."
    dockerfile = "Dockerfile"
    no-cache   = true
    platforms  = ["linux/amd64"]
    args = {
        BEETS_VERSION    = BEETS_VERSION
        MUTAGEN_VERSION  = MUTAGEN_VERSION
        PYYAML_VERSION   = PYYAML_VERSION
        REQUESTS_VERSION = REQUESTS_VERSION
        LAP_VERSION      = LAP_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/beets:latest",
        "ghcr.io/mirceanton/beets:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/beets:date-${DATE}",
    ]

    labels = {
        "org.opencontainers.image.vendor"      = "Mircea-Pavel Anton"
        "org.opencontainers.image.source"      = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created"     = "${DATE}"
        "org.opencontainers.image.revision"    = "${GIT_SHA}"
        "org.opencontainers.image.licenses"    = "MIT"

        "org.opencontainers.image.title"       = "Beets Library Audit"
        "org.opencontainers.image.authors"     = "beetbox"
        "org.opencontainers.image.description" = "Music library metadata audit and reconciliation using beets and MusicBrainz"
        "org.opencontainers.image.url"         = "https://beets.io"
        "org.opencontainers.image.version"     = "${BEETS_VERSION}"
    }
}