#!/bin/bash

# shellcheck source=/dev/null

declare current_dir &&
    current_dir="$(dirname "${BASH_SOURCE[0]}")" &&
    cd "${current_dir}" &&
    source "$HOME/set-me-up/dotfiles/utilities/import.sh"

smu::import base
smu::import system
smu::import homebrew

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

install_agent_browser_npm() {
    if ! cmd_exists "npm"; then
        error "npm is required to install agent-browser without Homebrew"
        return 1
    fi

    npm install -g agent-browser
}

install_agent_browser_chrome() {
    # Downloads Chrome for Testing on first use. Safe to re-run.
    agent-browser install
}

install_agent_browser_skill() {
    if ! cmd_exists "npx"; then
        return 0
    fi

    # Best-effort non-interactive skill install for agent harnesses.
    npx --yes skills add vercel-labs/agent-browser -g -y >/dev/null 2>&1 || true
}

ensure_warp_mcp_entry() {
    local mcp_path="${HOME}/.warp/.mcp.json"
    local agent_browser_bin=""

    agent_browser_bin="$(command -v agent-browser || true)"
    if [[ -z "${agent_browser_bin}" ]]; then
        return 0
    fi

    mkdir -p "${HOME}/.warp"

    if [[ ! -f "${mcp_path}" ]]; then
        cat >"${mcp_path}" <<EOF
{
  "mcpServers": {
    "agent-browser": {
      "command": "${agent_browser_bin}",
      "args": ["mcp", "--tools", "all"]
    }
  }
}
EOF
        return 0
    fi

    if ! cmd_exists "python3"; then
        return 0
    fi

    AGENT_BROWSER_BIN="${agent_browser_bin}" MCP_PATH="${mcp_path}" python3 - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["MCP_PATH"])
binary = os.environ["AGENT_BROWSER_BIN"]
try:
    data = json.loads(path.read_text())
except Exception:
    data = {}

key = "mcpServers"
if "mcp_servers" in data:
    key = "mcp_servers"
elif "servers" in data and "mcpServers" not in data:
    key = "servers"

servers = data.get(key)
if not isinstance(servers, dict):
    servers = {}

servers["agent-browser"] = {
    "command": binary,
    "args": ["mcp", "--tools", "all"],
}
data[key] = servers
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    ask_for_sudo

    # Always apply the brewfile when brew exists so companion deps
    # (ffmpeg) stay present even if agent-browser was installed earlier.
    if cmd_exists "brew"; then
        brew_bundle_install -f "brewfile"
    elif ! cmd_exists "agent-browser"; then
        install_agent_browser_npm
    fi

    if ! cmd_exists "agent-browser"; then
        error "agent-browser is not available on PATH after install"
        return 1
    fi

    install_agent_browser_chrome
    install_agent_browser_skill
    ensure_warp_mcp_entry

}

main
