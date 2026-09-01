#!/usr/bin/env bash
set -euo pipefail

log() { echo "[claude-remote-control] $*"; }

# ---------------------------------------------------------------------------
# ~/.claude.json holds mise -- sorry, Claude Code's -- per-directory trust map
# and user-scope MCP servers. It's a FILE next to ~/.claude/, not inside it,
# so it doesn't survive on a volume mounted only at ~/.claude. Persist it by
# keeping the real file on that volume and symlinking it into place.
# ---------------------------------------------------------------------------
CONFIG_JSON="${HOME}/.claude/.claude.json"
if [ ! -f "${CONFIG_JSON}" ]; then
  log "no persisted config yet, initializing ${CONFIG_JSON}"
  echo '{}' >"${CONFIG_JSON}"
fi
ln -sf "${CONFIG_JSON}" "${HOME}/.claude.json"

WORKSPACE_DIR="${CLAUDE_WORKSPACE_DIR:-${HOME}/workspace}"
mkdir -p "${WORKSPACE_DIR}"

MCP_CONFIG_FILE="${CLAUDE_MCP_CONFIG_FILE:-/etc/claude/mcp-servers.json}"

# ---------------------------------------------------------------------------
# Two things every boot, done together in one small node script so there's
# no window where a half-written ~/.claude.json could break the session:
#   1. Pre-trust WORKSPACE_DIR, so the server doesn't block on first launch
#      waiting for a trust dialog nobody is connected yet to answer. Repos
#      cloned later underneath it are each their own git repo and still get
#      trusted the normal way -- once, live, forwarded to whatever device
#      is connected -- same as any other Claude Code checkout.
#   2. Merge the mounted MCP server config (if any) into mcpServers, so it
#      stays declarative from the ConfigMap/Secret instead of hand-edited.
# ---------------------------------------------------------------------------
node -e '
const fs = require("fs");
const [, configPath, workspaceDir, mcpConfigPath] = process.argv;

const config = JSON.parse(fs.readFileSync(configPath, "utf8") || "{}");

config.projects = config.projects || {};
config.projects[workspaceDir] = config.projects[workspaceDir] || {};
config.projects[workspaceDir].hasTrustDialogAccepted = true;

if (fs.existsSync(mcpConfigPath)) {
  const mounted = JSON.parse(fs.readFileSync(mcpConfigPath, "utf8") || "{}");
  config.mcpServers = mounted.mcpServers || mounted || {};
}

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
' "${CONFIG_JSON}" "${WORKSPACE_DIR}" "${MCP_CONFIG_FILE}"

cd "${WORKSPACE_DIR}"

log "HOME=${HOME}  workspace=${WORKSPACE_DIR}"
log "starting: claude remote-control $*"
exec claude remote-control "$@"
