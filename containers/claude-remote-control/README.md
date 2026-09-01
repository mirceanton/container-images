# `claude-remote-control` Container Image

Runs [Claude Code](https://github.com/anthropics/claude-code) as an always-on `claude remote-control` server, so it shows up as a "device" in the Claude mobile app / claude.ai/code — meant to run as a long-lived pod rather than on a laptop.

mise is used only to bootstrap the Node.js runtime `claude` itself needs. It stays installed and live in the final image (not stripped after build), because it's also how *other* tools resolve: every repo the agent works in pins its own `kubectl`/`helm`/`go`/etc. versions in its own `mise.toml`, and mise auto-installs/auto-trusts those on `cd` at runtime. Nothing beyond Node is baked into this image on purpose -- see [Included tooling](#included-tooling).

## Usage

```bash
docker pull ghcr.io/mirceanton/claude-remote-control:latest
```

```bash
docker run --rm -it \
  -v claude-mise-cache:/home/claude/.mise \
  -v claude-credentials:/home/claude/.claude \
  ghcr.io/mirceanton/claude-remote-control:latest \
  --spawn=same-dir --capacity=4 --name my-server
```

The entrypoint execs `claude remote-control "$@"`, so any flag `claude remote-control` accepts (`--spawn`, `--capacity`, `--name`, `--permission-mode`, ...) can be passed straight to `docker run`/the container's `args:` instead of being baked into the image.

First run needs an interactive `claude /login` against the same `~/.claude` volume before Remote Control will authenticate -- see the `claude-remote-control` app's README in `home-ops` for the one-off login pod.

### Volumes

| Path                | Purpose                                                                 | Persist? |
| -------------------- | ------------------------------------------------------------------------ | :------: |
| `/home/claude/.mise`  | mise's data + cache dirs (`MISE_DATA_DIR`/`MISE_CACHE_DIR`) -- every tool mise installs for whatever repo you're in | yes |
| `/home/claude/.claude` | `claude /login` OAuth credentials, plus `.claude.json` (symlinked in from here -- see below) | yes |
| `/home/claude/workspace` | default working directory the server starts its first session in | no (ephemeral by design; clone repos here) |

### Config the entrypoint reads

| Env var | Default | Purpose |
| --- | --- | --- |
| `CLAUDE_WORKSPACE_DIR` | `$HOME/workspace` | Directory the entrypoint pre-trusts and starts the server in |
| `CLAUDE_MCP_CONFIG_FILE` | `/etc/claude/mcp-servers.json` | Optional mounted file; if present, its `mcpServers` object is merged into `~/.claude.json` on every boot |

`~/.claude.json` (Claude Code's per-directory trust map + user-scope MCP server list) lives next to `~/.claude/`, not inside it, so on its own it wouldn't survive on a volume mounted at `~/.claude`. The entrypoint keeps the real file at `~/.claude/.claude.json` (on the same volume) and symlinks `~/.claude.json` to it, then on every boot: marks `CLAUDE_WORKSPACE_DIR` as trusted (so the server doesn't block on a trust dialog nobody's connected yet to answer) and merges in the mounted MCP config, if any. Repos you clone *underneath* the workspace dir are their own git repos and still get a normal one-time trust prompt -- forwarded live to whatever device is connected -- same as any other Claude Code checkout.

### Never set `ANTHROPIC_BASE_URL`

Remote Control requires talking to `api.anthropic.com` directly and refuses to start if `ANTHROPIC_BASE_URL` points anywhere else (an LLM gateway/proxy included), or if `ANTHROPIC_API_KEY`/`CLAUDE_CODE_USE_BEDROCK`/`CLAUDE_CODE_USE_VERTEX` are set, or if `DISABLE_TELEMETRY`/`DO_NOT_TRACK`/`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`/`DISABLE_GROWTHBOOK` are set (these disable the feature-flag check Remote Control eligibility depends on). This image intentionally sets none of them -- don't add any when deploying it.

### Liveness

No HTTP port is exposed -- `claude remote-control` only makes outbound HTTPS calls. The image ships a Docker `HEALTHCHECK` that checks the process is still running:

```dockerfile
HEALTHCHECK CMD pgrep -f "remote-control" || exit 1
```

For Kubernetes, use the equivalent `exec` probe instead of `httpGet`:

```yaml
livenessProbe:
  exec:
    command: ["pgrep", "-f", "remote-control"]
  initialDelaySeconds: 30
  periodSeconds: 30
```

This only proves the process hasn't exited (it can't detect a hung-but-alive process) -- but since the entrypoint `exec`s `claude` as PID 1, a real crash already exits the container and gets caught by `restartPolicy`/Kubernetes on its own.

## Included tooling

- `mise` -- present and active at runtime (shims on `PATH`), used only to bootstrap Node at build time and to resolve whatever tools *other* repos pin at runtime
- Node.js `24.20.0` (LTS), installed via mise
- `@anthropic-ai/claude-code` (`claude` CLI), installed via `npm install -g` into a fixed, node-version-independent prefix
- `git`, `openssh-client`, `curl`, `unzip`, `ca-certificates` -- baseline utilities, not version-pinned project tooling

Deliberately **not** included: `kubectl`, `helm`, `k9s`, `go`, or any other project-specific tool. Those are pinned per-repo in each repo's own `mise.toml` and resolve at runtime -- baking them into this image would create a second, drifting source of truth.
