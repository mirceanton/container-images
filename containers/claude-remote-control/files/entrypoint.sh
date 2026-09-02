#!/usr/bin/env bash
set -euo pipefail

log() { echo "[claude-remote-control] $*"; }

# ~/.claude.json (trust map + user-scope MCP servers) lives next to ~/.claude/,
# not inside it, so it won't survive on a volume mounted only at ~/.claude
# unless we relocate the real file onto that volume and symlink it into place.
CONFIG_JSON="${HOME}/.claude/.claude.json"
if [ ! -f "${CONFIG_JSON}" ]; then
  log "no persisted config yet, initializing ${CONFIG_JSON}"
  echo '{}' >"${CONFIG_JSON}"
fi
ln -sf "${CONFIG_JSON}" "${HOME}/.claude.json"

WORKSPACE_DIR="${CLAUDE_WORKSPACE_DIR:-${HOME}/workspace}"
mkdir -p "${WORKSPACE_DIR}"

MCP_CONFIG_FILE="${CLAUDE_MCP_CONFIG_FILE:-/etc/claude/mcp-servers.json}"

# Pre-trust WORKSPACE_DIR (so the server doesn't block on first launch with
# nobody connected to answer the trust dialog -- repos cloned under it later
# are separate git repos and still get a normal live trust prompt) and merge
# in the mounted MCP config, if any. Both in one script so there's no window
# where a half-written ~/.claude.json could break the session.
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
