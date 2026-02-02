# Terragrunt Container Images

Container images for [Terragrunt](https://github.com/gruntwork-io/terragrunt), a flexible orchestration tool for Infrastructure as Code.

## Image Variants

### Binary-only (`:X.Y.Z`)

A minimal `scratch`-based image containing only the Terragrunt binary at `/terragrunt`. This image is **not meant to be run directly** - it's intended for use in multi-stage builds to copy the binary into your own images.

```dockerfile
FROM ghcr.io/mirceanton/terragrunt:0.99.1 AS terragrunt

FROM whatever
COPY --from=terragrunt /terragrunt /usr/local/bin/terragrunt
# ... rest of your image
```

### Terraform (`:terraform-*`)

Terragrunt bundled with [Terraform](https://github.com/hashicorp/terraform). Ready to use out of the box.

```bash
docker pull ghcr.io/mirceanton/terragrunt:terraform
```

### OpenTofu (`:opentofu-*`)

Terragrunt bundled with [OpenTofu](https://github.com/opentofu/opentofu). Ready to use out of the box.

```bash
docker pull ghcr.io/mirceanton/terragrunt:opentofu
```

## Tag Naming Convention

> [!Note]
> Due to what appears to be a GHCR UI limitation, not all tags may be visible in the web interface. However, all tags listed below are available and can be pulled.

### Binary-only Image

| Tag Pattern    | Example            | Description                    |
| -------------- | ------------------ | ------------------------------ |
| `:X.Y.Z`       | `:0.99.1`          | Specific terragrunt version    |
| `:X.Y`         | `:0.99`            | Latest patch for minor version |
| `:X`           | `:0`               | Latest for major version       |
| `:sha-<hash>`  | `:sha-abc123`      | Specific git commit            |
| `:date-<date>` | `:date-2026.02.02` | Build date                     |

### Terraform/OpenTofu Images

| Tag Pattern        | Example             | Description                                           |
| ------------------ | ------------------- | ----------------------------------------------------- |
| `:terraform`       | -                   | Latest terragrunt + latest terraform                  |
| `:terraform-X.Y.Z` | `:terraform-1.14.4` | Latest terragrunt + specific terraform                |
| `:terraform-X.Y`   | `:terraform-1.14`   | Latest terragrunt + terrform pinned to minor version  |
| `:terraform-X`     | `:terraform-1`      | Latest terragrunt + terraform pinned to major version |
| `:opentofu`        | -                   | Latest terragrunt + latest opentofu                   |
| `:opentofu-X.Y.Z`  | `:opentofu-1.11.4`  | Latest terragrunt + specific opentofu                 |
| `:opentofu-X.Y`    | `:opentofu-1.11`    | Latest terragrunt + opentofu pinned to minor version  |
| `:opentofu-X`      | `:opentofu-1`       | Latest terragrunt + opentofu pinned to major version  |

#### Combined Version Tags

For full control over both versions, combined tags are available in the format `:TG_VERSION-terraform-TF_VERSION`. All combinations of version granularity are supported:

| Terragrunt | Terraform/OpenTofu | Example                    |
| ---------- | ------------------ | -------------------------- |
| `X.Y.Z`    | `X.Y.Z`            | `:0.99.1-terraform-1.14.4` |
| `X.Y.Z`    | `X.Y`              | `:0.99.1-terraform-1.14`   |
| `X.Y.Z`    | `X`                | `:0.99.1-terraform-1`      |
| `X.Y`      | `X.Y.Z`            | `:0.99-terraform-1.14.4`   |
| `X.Y`      | `X.Y`              | `:0.99-terraform-1.14`     |
| `X.Y`      | `X`                | `:0.99-terraform-1`        |
| `X`        | `X.Y.Z`            | `:0-terraform-1.14.4`      |
| `X`        | `X.Y`              | `:0-terraform-1.14`        |
| `X`        | `X`                | `:0-terraform-1`           |

The same patterns apply for OpenTofu (replace `terraform` with `opentofu`).
