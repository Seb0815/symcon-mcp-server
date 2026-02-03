#!/usr/bin/env bash
# MCP-Server lokal auf dem Mac starten (Workaround wenn SymBox:4096 nicht erreichbar).
# Symcon-API bleibt auf der SymBox (z. B. http://192.168.10.12:3777/api/).
#
# Vor dem Start: In der mcp.json die Symcon-URL auf http://127.0.0.1:4096 stellen,
# dann Cursor neu starten. Dieses Skript im Projektordner ausführen und laufen lassen.
#
# Nutzung:
#   ./start-mcp-local.sh [SYMCON_API_URL] [MCP_API_KEY] [SYMCON_API_USER] [SYMCON_API_PASSWORD]
#
# Beispiele:
#   ./start-mcp-local.sh
#   ./start-mcp-local.sh http://192.168.10.12:3777/api/ 9984e9820eef...                           # MCP-API-Key (optional)
#   ./start-mcp-local.sh http://192.168.10.12:3777/api/ 9984e9820eef... "lizenz@mail.tld" "Pass!"  # zusätzlich Symcon-Remote-Access (Basic-Auth)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_DIR="$SCRIPT_DIR/libs/mcp-server"
SYMCON_URL="${1:-http://192.168.10.12:3777/api/}"
MCP_API_KEY="${2:-}"
SYMCON_USER="${3:-}"
SYMCON_PASS="${4:-}"

echo "Starte MCP-Server lokal (Port 4096), Symcon-API: $SYMCON_URL"
echo "In Cursor MCP-URL auf http://127.0.0.1:4096 stellen, dann Cursor neu starten."
if [ -n "$SYMCON_USER" ] || [ -n "$SYMCON_PASS" ]; then
  echo "Symcon-Auth: Basic-Auth aktiv (Remote Access)."
fi
echo "Beenden mit Ctrl+C."
echo ""

export MCP_PORT=4096
export SYMCON_API_URL="$SYMCON_URL"
[ -n "$MCP_API_KEY" ] && export MCP_AUTH_TOKEN="$MCP_API_KEY"
[ -n "$SYMCON_USER" ] && export SYMCON_API_USER="$SYMCON_USER"
[ -n "$SYMCON_PASS" ] && export SYMCON_API_PASSWORD="$SYMCON_PASS"

cd "$MCP_DIR"
exec npm run start
