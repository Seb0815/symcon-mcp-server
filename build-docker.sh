#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Symcon MCP Server - Docker Build                                 ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  WARNUNG: .env-Datei nicht gefunden!"
    echo ""
    echo "Bitte erstellen Sie zuerst eine .env-Datei:"
    echo "  1. Kopieren: cp .env.example .env"
    echo "  2. ODER: ./scripts/setup-env.sh ausführen"
    echo ""
    exit 1
fi

# Get version from library.json (robust)
VERSION=$(python3 - <<'PY'
import json
with open('library.json', 'r', encoding='utf-8') as f:
    print(json.load(f).get('version', '2.0.0'))
PY
)
if [ -z "$VERSION" ]; then
    VERSION="2.0.0"
fi

echo "📦 Building MCP Server v$VERSION..."
echo ""

# Build Docker image (TypeScript build happens inside Dockerfile)
echo "→ Baue Docker Image (inkl. TypeScript Build im Container)..."
docker build -t symcon-mcp-server:latest -f libs/mcp-server/Dockerfile libs/mcp-server
docker tag symcon-mcp-server:latest symcon-mcp-server:$VERSION
echo "  ✓ Docker Image gebaut"
echo ""

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  ✓ Build erfolgreich!                                             ║"
echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║  Images:                                                           ║"
echo "║    - symcon-mcp-server:latest                                      ║"
echo "║    - symcon-mcp-server:$VERSION"
echo "║                                                                    ║"
echo "║  Nächster Schritt:                                                 ║"
echo "║    ./start-docker.sh                                               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
