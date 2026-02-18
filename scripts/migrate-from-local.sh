#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Symcon MCP Server - Migration v1.x → v2.0 (Docker)               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Dieses Script migriert Ihre bestehende Installation auf Docker."
echo ""

# Check if old installation exists
PID_FILES=$(find MCPServer -name ".mcp_server_*.pid" 2>/dev/null || true)

if [ -n "$PID_FILES" ]; then
    echo "→ Alte Node.js-Prozesse gefunden, stoppe..."
    for pidfile in $PID_FILES; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            echo "  Stoppe PID $pid..."
            kill "$pid" 2>/dev/null || true
            rm "$pidfile"
        fi
    done
    echo "  ✓ Alte Prozesse gestoppt"
    echo ""
else
    echo "ℹ️  Keine laufenden Node.js-Prozesse gefunden"
    echo ""
fi

# Backup Knowledge Store
if [ -f "libs/mcp-server/data/symcon-knowledge.json" ]; then
    echo "→ Sichere Knowledge Store..."
    cp libs/mcp-server/data/symcon-knowledge.json libs/mcp-server/data/symcon-knowledge.json.backup
    echo "  ✓ Backup erstellt: symcon-knowledge.json.backup"
    echo ""
fi

if [ -f "libs/mcp-server/data/symcon-automations.json" ]; then
    echo "→ Sichere Automation Store..."
    cp libs/mcp-server/data/symcon-automations.json libs/mcp-server/data/symcon-automations.json.backup
    echo "  ✓ Backup erstellt: symcon-automations.json.backup"
    echo ""
fi

# Create .env if it doesn't exist
if [ -f .env ]; then
    echo "ℹ️  .env-Datei existiert bereits"
    echo ""
else
    echo "→ Erstelle .env-Datei..."
    
    # Try to extract API key from Symcon module config (if accessible)
    # This is a best-effort attempt, may not work in all setups
    
    # For now, copy from example and prompt user
    cp .env.example .env
    
    # Generate API key
    API_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p)
    
    # Set API key in .env
    sed -i.bak "s/^MCP_AUTH_TOKEN=.*/MCP_AUTH_TOKEN=$API_KEY/" .env
    rm .env.bak
    
    echo "  ✓ .env-Datei erstellt"
    echo ""
    echo "  📋 Generierter API-Key:"
    echo "     $API_KEY"
    echo ""
    echo "  ⚠️  WICHTIG: Diesen Key auch im Symcon-Modul eintragen!"
    echo ""
fi

# Check Symcon API URL
echo "→ Konfiguration überprüfen..."
echo ""
read -p "Symcon-API-URL [http://127.0.0.1:3777/api/]: " SYMCON_URL
SYMCON_URL=${SYMCON_URL:-http://127.0.0.1:3777/api/}

# Update .env with Symcon URL
sed -i.bak "s|^SYMCON_API_URL=.*|SYMCON_API_URL=$SYMCON_URL|" .env
rm .env.bak

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  ✓ Migration abgeschlossen!                                       ║"
echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║  Nächste Schritte:                                                 ║"
echo "║                                                                    ║"
echo "║  1. Docker-Image bauen:                                            ║"
echo "║     → ./build-docker.sh                                            ║"
echo "║                                                                    ║"
echo "║  2. Docker-Container starten:                                      ║"
echo "║     → ./start-docker.sh                                            ║"
echo "║                                                                    ║"
echo "║  3. In Symcon-Modul:                                               ║"
echo "║     → MCP Server URL: http://localhost:4096                        ║"
echo "║     → API-Key aus .env kopieren und eintragen                      ║"
echo "║     → 'Änderungen übernehmen' klicken                              ║"
echo "║                                                                    ║"
echo "║  Knowledge Store wurde beibehalten (in libs/mcp-server/data/)      ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
