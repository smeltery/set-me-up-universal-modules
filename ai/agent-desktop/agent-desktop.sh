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

install_agent_desktop_npm() {
    if ! cmd_exists "npm"; then
        error "npm is required to install agent-desktop without Homebrew"
        return 1
    fi

    npm install -g agent-desktop
}

install_agent_desktop_skill() {
    if ! cmd_exists "npx"; then
        return 0
    fi

    # Best-effort non-interactive skill install for agent harnesses.
    npx --yes skills add https://github.com/vercel-labs/agent-desktop --skill agent-desktop -g -y >/dev/null 2>&1 || true
}

ensure_warp_mcp_entry() {
    local mcp_path="${HOME}/.warp/.mcp.json"
    local agent_desktop_bin=""

    agent_desktop_bin="$(command -v agent-desktop || true)"
    if [[ -z "${agent_desktop_bin}" ]]; then
        return 0
    fi

    mkdir -p "${HOME}/.warp"

    if [[ ! -f "${mcp_path}" ]]; then
        cat >"${mcp_path}" <<EOF
{
  "mcpServers": {
    "agent-desktop": {
      "command": "${agent_desktop_bin}",
      "args": ["mcp"]
    }
  }
}
EOF
        return 0
    fi

    if ! cmd_exists "python3"; then
        return 0
    fi

    AGENT_DESKTOP_BIN="${agent_desktop_bin}" MCP_PATH="${mcp_path}" python3 - <<'PY'
import json
import os
from pathlib import Path

path = Path(os.environ["MCP_PATH"])
binary = os.environ["AGENT_DESKTOP_BIN"]
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

servers["agent-desktop"] = {
    "command": binary,
    "args": ["mcp"],
}
data[key] = servers
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

print_macos_permissions_hint() {
    if ! is_macos; then
        return 0
    fi

    # status is compact JSON; missing granted accessibility is a reminder only.
    if agent-desktop status 2>/dev/null | grep -q '"accessibility":{"state":"granted"'; then
        return 0
    fi

    warn "agent-desktop needs macOS Accessibility (and Screen Recording for screenshots)."
    warn "Run: agent-desktop permissions --guide"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

main() {

    ask_for_sudo

    if cmd_exists "brew"; then
        brew_bundle_install -f "brewfile"
    elif ! cmd_exists "agent-desktop"; then
        install_agent_desktop_npm
    fi

    if ! cmd_exists "agent-desktop"; then
        error "agent-desktop is not available on PATH after install"
        return 1
    fi

    install_agent_desktop_skill
    ensure_warp_mcp_entry
    print_macos_permissions_hint

}

main
