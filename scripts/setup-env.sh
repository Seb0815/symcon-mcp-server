#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Symcon MCP Server - Interaktives Setup                           ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Dieses Script hilft Ihnen beim Einrichten der .env-Datei."
echo ""

# Check if .env already exists
if [ -f .env ]; then
    echo "⚠️  .env-Datei existiert bereits!"
    echo ""
    read -p "Möchten Sie sie überschreiben? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Abgebrochen."
        exit 0
    fi
    mv .env .env.backup.$(date +%s)
    echo "  → Backup erstellt: .env.backup.*"
    echo ""
fi

# Copy example
cp .env.example .env

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Konfiguration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# MCP Port
read -p "MCP Server Port [4096]: " MCP_PORT
MCP_PORT=${MCP_PORT:-4096}
sed -i.bak "s/^MCP_PORT=.*/MCP_PORT=$MCP_PORT/" .env

echo ""

# Symcon API URL
echo "Symcon-API-URL (z.B. http://192.168.1.100:3777/api/)"
read -p "Symcon-API-URL [http://127.0.0.1:3777/api/]: " SYMCON_URL
SYMCON_URL=${SYMCON_URL:-http://127.0.0.1:3777/api/}
sed -i.bak "s|^SYMCON_API_URL=.*|SYMCON_API_URL=$SYMCON_URL|" .env

echo ""

# Symcon Authentication (optional)
read -p "Verwendet Symcon Remote Access mit Authentifizierung? [y/N]: " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Symcon-Benutzername (E-Mail): " SYMCON_USER
    sed -i.bak "s/^SYMCON_API_USER=.*/SYMCON_API_USER=$SYMCON_USER/" .env
    
    read -sp "Symcon-Passwort: " SYMCON_PASS
    echo ""
    sed -i.bak "s/^SYMCON_API_PASSWORD=.*/SYMCON_API_PASSWORD=$SYMCON_PASS/" .env
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  API-Schlüssel generieren"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Generate API key
echo "→ Generiere sicheren API-Schlüssel (64 Zeichen)..."
API_KEY=$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p | tr -d '\n')
sed -i.bak "s/^MCP_AUTH_TOKEN=.*/MCP_AUTH_TOKEN=$API_KEY/" .env

echo "  ✓ API-Schlüssel generiert"
echo ""

# Cleanup backup files
rm -f .env.bak

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verbindung testen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "→ Teste Verbindung zu Symcon-API..."

# Test Symcon connection
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$SYMCON_URL" -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"IPS_GetKernelVersion","params":[],"id":1}' \
  --max-time 5 || echo "000")

if [ "$RESPONSE" = "200" ]; then
    echo "  ✓ Symcon-API erreichbar"
elif [ "$RESPONSE" = "401" ]; then
    echo "  ⚠️  Symcon-API antwortet, aber Authentifizierung erforderlich"
    echo "     Prüfen Sie SYMCON_API_USER und SYMCON_API_PASSWORD"
else
    echo "  ✗ Symcon-API nicht erreichbar (HTTP $RESPONSE)"
    echo "     Prüfen Sie die SYMCON_API_URL"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Sicherheit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "→ Setze sichere Dateiberechtigungen..."
chmod 600 .env
echo "  ✓ .env ist nur für Besitzer lesbar (chmod 600)"
echo ""

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  ✓ Setup abgeschlossen!                                           ║"
echo "╠════════════════════════════════════════════════════════════════════╣"
echo "║                                                                    ║"
echo "║  📋 Generierter API-Schlüssel (für Symcon-Modul):                 ║"
echo "║  ┌──────────────────────────────────────────────────────────────┐ ║"
echo "║  │ $API_KEY │ ║"
echo "║  └──────────────────────────────────────────────────────────────┘ ║"
echo "║                                                                    ║"
echo "║  Nächste Schritte:                                                 ║"
echo "║    1. ./build-docker.sh                                            ║"
echo "║    2. ./start-docker.sh                                            ║"
echo "║    3. API-Key in Symcon-Modul eintragen                            ║"
echo "║                                                                    ║"
echo "║  Konfiguration gespeichert in: .env                                ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
