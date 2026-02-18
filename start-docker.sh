#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Symcon MCP Server - Docker Start                                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ FEHLER: .env-Datei nicht gefunden!"
    echo ""
    echo "Bitte erstellen Sie zuerst eine .env-Datei:"
    echo "  ./scripts/setup-env.sh"
    echo ""
    exit 1
fi

# Check if MCP_AUTH_TOKEN is set
if ! grep -q "^MCP_AUTH_TOKEN=.\+" .env; then
    echo "❌ FEHLER: MCP_AUTH_TOKEN ist nicht in der .env-Datei gesetzt!"
    echo ""
    echo "Der MCP-Server benötigt einen API-Key für die Authentifizierung."
    echo "Bitte führen Sie aus:"
    echo "  ./scripts/setup-env.sh"
    echo ""
    exit 1
fi

echo "→ Starte Docker-Container..."
docker-compose up -d

echo ""
echo "→ Warte 5 Sekunden auf Container-Start..."
sleep 5

# Get port from .env
PORT=$(grep "^MCP_PORT=" .env | cut -d'=' -f2)
if [ -z "$PORT" ]; then
    PORT="4096"
fi

# Health check
echo "→ Prüfe Health-Check..."
if curl -s -f http://localhost:$PORT/health > /dev/null; then
    echo "  ✓ MCP Server läuft"
    
    # Get version from health endpoint
    VERSION=$(curl -s http://localhost:$PORT/health | grep -o '"version":"[^"]*' | cut -d'"' -f4)
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  ✓ MCP Server gestartet!                                          ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║  Version:    $VERSION"
    echo "║  URL:        http://localhost:$PORT"
    echo "║  Health:     http://localhost:$PORT/health"
    echo "║                                                                    ║"
    echo "║  Logs anzeigen:                                                    ║"
    echo "║    docker logs -f symcon-mcp-server                                ║"
    echo "║                                                                    ║"
    echo "║  Nächster Schritt:                                                 ║"
    echo "║    1. API-Key aus .env kopieren (MCP_AUTH_TOKEN)                   ║"
    echo "║    2. In Symcon-Modul eintragen                                    ║"
    echo "║    3. MCP Server URL: http://localhost:$PORT"
    echo "╚════════════════════════════════════════════════════════════════════╝"
else
    echo "  ✗ Health-Check fehlgeschlagen"
    echo ""
    echo "Container-Status:"
    docker ps -a | grep symcon-mcp-server || true
    echo ""
    echo "Letzte 20 Log-Zeilen:"
    docker logs --tail 20 symcon-mcp-server 2>&1 || true
    echo ""
    echo "Prüfen Sie die Logs mit: docker logs symcon-mcp-server"
    exit 1
fi
