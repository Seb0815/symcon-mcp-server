#!/usr/bin/env bash
# Deploy PHP-Modul zur SymBox.
# WICHTIG: Der MCP-Server läuft jetzt in Docker, nicht mehr auf der SymBox!
# Dieses Script deployed nur noch das PHP-Modul (Docker-Client).
#
# Voraussetzung: SSH-Zugang (z. B. root@<SymBox-IP>), Passwort wird ggf. abgefragt.
#
# Nutzung:
#   ./deploy-to-symbox.sh root@<SymBox-IP>

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"
MODULE_DIR="$SCRIPT_DIR/MCPServer"
REMOTE="${1:?Usage: $0 root@<SymBox-IP>}"
REMOTE_PATH="/var/lib/symcon/modules/symcon-mcp-server"

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Deploy PHP-Modul zur SymBox                                       ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  HINWEIS: Der MCP-Server läuft in Docker, nicht auf der SymBox!"
echo "   Das PHP-Modul ist jetzt nur noch ein HTTP-Client."
echo ""

echo "→ Kopiere Repository nach $REMOTE:$REMOTE_PATH/"
ssh "$REMOTE" "mkdir -p $REMOTE_PATH"
scp -r "$REPO_DIR/library.json" "$REMOTE:$REMOTE_PATH/"
scp -r "$MODULE_DIR" "$REMOTE:$REMOTE_PATH/"

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  ✓ Deployment abgeschlossen                                       ║"
echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║  Nächste Schritte:                                                 ║"
echo "║    1. Docker-MCP-Server starten (auf Docker-Host)                  ║"
echo "║       → ./start-docker.sh                                          ║"
echo "║                                                                    ║"
echo "║    2. In Symcon-Weboberfläche:                                     ║"
echo "║       → Module Control: Repository aktualisieren                   ║"
echo "║       → Modul 'MCP Server' öffnen                                  ║"
echo "║       → MCP Server URL: http://<DOCKER-HOST>:4096                  ║"
echo "║       → API-Key aus .env eintragen                                 ║"
echo "║       → 'Änderungen übernehmen' klicken                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
