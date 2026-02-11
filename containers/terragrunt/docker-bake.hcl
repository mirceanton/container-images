DATE = formatdate("YYYY.MM.DD", timestamp())
variable "GIT_SHA" {}

variable "TERRAGRUNT_VERSION" {
    # renovate: datasource=github-releases depName=gruntwork-io/terragrunt
    default = "0.99.1"
}

variable "TERRAFORM_VERSION" {
    # renovate: datasource=github-releases depName=hashicorp/terraform
    default = "1.14.5"
}

variable "OPENTOFU_VERSION" {
    # renovate: datasource=github-releases depName=opentofu/opentofu
    default = "1.11.4"
}

# ===============================================================================
# Binary-only image (for multi-stage builds)
# ===============================================================================
target "base" {
    context = "."
    dockerfile = "Dockerfile.base"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        TERRAGRUNT_VERSION = TERRAGRUNT_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/terragrunt:latest",
        "ghcr.io/mirceanton/terragrunt:sha-${GIT_SHA}",
        "ghcr.io/mirceanton/terragrunt:date-${DATE}",
        "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "terragrunt"
        "org.opencontainers.image.authors" = "Gruntwork"
        "org.opencontainers.image.description" = "Terragrunt binary-only image for use in multi-stage builds (COPY --from)"
        "org.opencontainers.image.url" = "https://github.com/gruntwork-io/terragrunt"
        "org.opencontainers.image.version" = "${TERRAGRUNT_VERSION}"
    }
}

# ===============================================================================
# Terraform image (terragrunt + terraform)
# ===============================================================================
target "terraform" {
    context = "."
    dockerfile = "Dockerfile.terraform"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        TERRAGRUNT_VERSION = TERRAGRUNT_VERSION
        TERRAFORM_VERSION = TERRAFORM_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/terragrunt:terraform",
        "ghcr.io/mirceanton/terragrunt:terraform-sha-${GIT_SHA}",
        "ghcr.io/mirceanton/terragrunt:terraform-date-${DATE}",

        # Terraform version only tags
        "ghcr.io/mirceanton/terragrunt:terraform-${TERRAFORM_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:terraform-${regex("^([0-9]+\\.[0-9]+)", TERRAFORM_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:terraform-${regex("^([0-9]+)", TERRAFORM_VERSION)[0]}" : "",

        # Combined version tags: TG X.Y.Z with TF X.Y.Z / X.Y / X
        "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}-terraform-${TERRAFORM_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}-terraform-${regex("^([0-9]+\\.[0-9]+)", TERRAFORM_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}-terraform-${regex("^([0-9]+)", TERRAFORM_VERSION)[0]}" : "",

        # Combined version tags: TG X.Y with TF X.Y.Z / X.Y / X
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}-terraform-${TERRAFORM_VERSION}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}-terraform-${regex("^([0-9]+\\.[0-9]+)", TERRAFORM_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}-terraform-${regex("^([0-9]+)", TERRAFORM_VERSION)[0]}" : "",

        # Combined version tags: TG X with TF X.Y.Z / X.Y / X
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}-terraform-${TERRAFORM_VERSION}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}-terraform-${regex("^([0-9]+\\.[0-9]+)", TERRAFORM_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAFORM_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}-terraform-${regex("^([0-9]+)", TERRAFORM_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "terragrunt-terraform"
        "org.opencontainers.image.authors" = "Gruntwork, HashiCorp"
        "org.opencontainers.image.description" = "Terragrunt with Terraform - Infrastructure as Code orchestration"
        "org.opencontainers.image.url" = "https://github.com/gruntwork-io/terragrunt"
        "org.opencontainers.image.version" = "${TERRAGRUNT_VERSION}-terraform-${TERRAFORM_VERSION}"
    }
}

# ===============================================================================
# OpenTofu image (terragrunt + opentofu)
# ===============================================================================
target "opentofu" {
    context = "."
    dockerfile = "Dockerfile.opentofu"
    no-cache = true
    platforms = ["linux/amd64", "linux/arm64"]
    args = {
        TERRAGRUNT_VERSION = TERRAGRUNT_VERSION
        OPENTOFU_VERSION = OPENTOFU_VERSION
    }

    tags = [
        "ghcr.io/mirceanton/terragrunt:opentofu",
        "ghcr.io/mirceanton/terragrunt:opentofu-sha-${GIT_SHA}",
        "ghcr.io/mirceanton/terragrunt:opentofu-date-${DATE}",

        # OpenTofu version only tags
        "ghcr.io/mirceanton/terragrunt:opentofu-${OPENTOFU_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:opentofu-${regex("^([0-9]+\\.[0-9]+)", OPENTOFU_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:opentofu-${regex("^([0-9]+)", OPENTOFU_VERSION)[0]}" : "",

        # Combined version tags: TG X.Y.Z with OT X.Y.Z / X.Y / X
        "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}-opentofu-${OPENTOFU_VERSION}",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}-opentofu-${regex("^([0-9]+\\.[0-9]+)", OPENTOFU_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${TERRAGRUNT_VERSION}-opentofu-${regex("^([0-9]+)", OPENTOFU_VERSION)[0]}" : "",

        # Combined version tags: TG X.Y with OT X.Y.Z / X.Y / X
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}-opentofu-${OPENTOFU_VERSION}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}-opentofu-${regex("^([0-9]+\\.[0-9]+)", OPENTOFU_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+\\.[0-9]+)", TERRAGRUNT_VERSION)[0]}-opentofu-${regex("^([0-9]+)", OPENTOFU_VERSION)[0]}" : "",

        # Combined version tags: TG X with OT X.Y.Z / X.Y / X
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}-opentofu-${OPENTOFU_VERSION}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}-opentofu-${regex("^([0-9]+\\.[0-9]+)", OPENTOFU_VERSION)[0]}" : "",
        can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", TERRAGRUNT_VERSION)) && can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+", OPENTOFU_VERSION)) ? "ghcr.io/mirceanton/terragrunt:${regex("^([0-9]+)", TERRAGRUNT_VERSION)[0]}-opentofu-${regex("^([0-9]+)", OPENTOFU_VERSION)[0]}" : ""
    ]

    labels = {
        "org.opencontainers.image.vendor" = "Mircea-Pavel Anton"
        "org.opencontainers.image.source" = "https://github.com/mirceanton/container-images"
        "org.opencontainers.image.created" = "${DATE}"
        "org.opencontainers.image.revision" = "${GIT_SHA}"
        "org.opencontainers.image.licenses" = "MIT"

        "org.opencontainers.image.title" = "terragrunt-opentofu"
        "org.opencontainers.image.authors" = "Gruntwork, OpenTofu"
        "org.opencontainers.image.description" = "Terragrunt with OpenTofu - Infrastructure as Code orchestration"
        "org.opencontainers.image.url" = "https://github.com/gruntwork-io/terragrunt"
        "org.opencontainers.image.version" = "${TERRAGRUNT_VERSION}-opentofu-${OPENTOFU_VERSION}"
    }
}

# ===============================================================================
# Group to build all targets
# ===============================================================================
group "default" {
    targets = ["base", "terraform", "opentofu"]
}
