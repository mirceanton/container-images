# Carbon Container Image

Container image for [Carbon](https://github.com/carbon-app/carbon), a tool to create and share beautiful images of your source code.

## Usage

```bash
docker pull ghcr.io/mirceanton/carbon:latest
```

### Basic Usage

```bash
docker run --rm -p 3000:3000 ghcr.io/mirceanton/carbon:latest
```

The app will be available at `http://localhost:3000`.

### With Environment Variables

Carbon supports optional Firebase integration for user accounts and saved snippets:

```bash
docker run --rm -p 3000:3000 \
  -e FIREBASE_API_KEY=<your-api-key> \
  -e FIREBASE_AUTH_DOMAIN=<your-project>.firebaseapp.com \
  -e FIREBASE_PROJECT_ID=<your-project-id> \
  ghcr.io/mirceanton/carbon:latest
```

## Included Tools

- `carbon` — Next.js web app for creating source code images
- `node` — JavaScript runtime (v18)
- `chromium` — Headless browser for server-side image export

## Tag Naming Convention

| Tag                | Description                      |
| ------------------ | -------------------------------- |
| `:latest`          | Latest release                   |
| `:X.Y.Z`           | Specific version                 |
| `:X.Y`             | Latest patch for minor version   |
| `:X`               | Latest release for major version |
| `:sha-<hash>`      | Specific git commit              |
| `:date-YYYY.MM.DD` | Build date                       |
