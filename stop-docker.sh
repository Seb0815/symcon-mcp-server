#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Symcon MCP Server - Docker Stop                                  ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if container is running
if docker ps | grep -q symcon-mcp-server; then
    echo "→ Stoppe Docker-Container..."
    docker-compose down
    echo "  ✓ Container gestoppt"
    echo ""
    
    # Ask about volume cleanup
    read -p "Soll der Daten-Volume gelöscht werden (Knowledge Store)? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "→ Lösche Volumes..."
        docker-compose down -v
        echo "  ✓ Volumes gelöscht"
        echo ""
        echo "⚠️  WARNUNG: Knowledge Store (.json-Dateien) wurden gelöscht!"
    fi
else
    echo "ℹ️  Container läuft nicht"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  ✓ MCP Server gestoppt                                            ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
