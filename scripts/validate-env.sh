#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║  Symcon MCP Server - .env Validierung                             ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ FEHLER: .env-Datei nicht gefunden!"
    echo "   Erstellen Sie sie mit: ./scripts/setup-env.sh"
    exit 1
fi

echo "→ Lese .env-Datei..."
echo ""

# Source .env
set -a
source .env
set +a

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Pflichtfelder prüfen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check MCP_PORT
if [ -z "$MCP_PORT" ]; then
    echo "❌ MCP_PORT ist nicht gesetzt"
    ERRORS=$((ERRORS + 1))
elif ! [[ "$MCP_PORT" =~ ^[0-9]+$ ]] || [ "$MCP_PORT" -lt 1024 ] || [ "$MCP_PORT" -gt 65535 ]; then
    echo "❌ MCP_PORT muss zwischen 1024 und 65535 liegen (aktuell: $MCP_PORT)"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ MCP_PORT: $MCP_PORT"
fi

# Check SYMCON_API_URL
if [ -z "$SYMCON_API_URL" ]; then
    echo "❌ SYMCON_API_URL ist nicht gesetzt"
    ERRORS=$((ERRORS + 1))
elif ! [[ "$SYMCON_API_URL" =~ ^https?:// ]]; then
    echo "❌ SYMCON_API_URL muss mit http:// oder https:// beginnen (aktuell: $SYMCON_API_URL)"
    ERRORS=$((ERRORS + 1))
else
    echo "✓ SYMCON_API_URL: $SYMCON_API_URL"
fi

# Check MCP_AUTH_TOKEN
if [ -z "$MCP_AUTH_TOKEN" ]; then
    echo "❌ MCP_AUTH_TOKEN ist nicht gesetzt (VERPFLICHTEND!)"
    ERRORS=$((ERRORS + 1))
elif [ ${#MCP_AUTH_TOKEN} -lt 16 ]; then
    echo "⚠️  MCP_AUTH_TOKEN ist zu kurz (< 16 Zeichen). Empfohlen: 32+ Zeichen"
    echo "   Aktuell: ${#MCP_AUTH_TOKEN} Zeichen"
else
    echo "✓ MCP_AUTH_TOKEN: ${#MCP_AUTH_TOKEN} Zeichen (gut)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Optionale Felder prüfen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -n "$SYMCON_API_USER" ]; then
    echo "ℹ️  SYMCON_API_USER: $SYMCON_API_USER"
    if [ -z "$SYMCON_API_PASSWORD" ]; then
        echo "⚠️  SYMCON_API_USER gesetzt, aber SYMCON_API_PASSWORD fehlt"
    fi
fi

if [ -n "$MCP_LOG_LEVEL" ]; then
    echo "ℹ️  MCP_LOG_LEVEL: $MCP_LOG_LEVEL"
fi

if [ -n "$MCP_RATE_LIMIT" ]; then
    echo "ℹ️  MCP_RATE_LIMIT: $MCP_RATE_LIMIT req/min"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Verbindungstest"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "→ Teste Symcon-API Erreichbarkeit..."

# Build auth header if needed
AUTH_HEADER=""
if [ -n "$SYMCON_API_USER" ] && [ -n "$SYMCON_API_PASSWORD" ]; then
    AUTH_HEADER="-u $SYMCON_API_USER:$SYMCON_API_PASSWORD"
fi

# Test connection
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" $AUTH_HEADER "$SYMCON_API_URL" -X POST \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"IPS_GetKernelVersion","params":[],"id":1}' \
  --max-time 10 2>/dev/null || echo "000")

if [ "$RESPONSE" = "200" ]; then
    echo "✓ Symcon-API erreichbar (HTTP 200)"
elif [ "$RESPONSE" = "401" ]; then
    echo "❌ Symcon-API: Authentifizierung fehlgeschlagen (HTTP 401)"
    echo "   Prüfen Sie SYMCON_API_USER und SYMCON_API_PASSWORD"
    ERRORS=$((ERRORS + 1))
elif [ "$RESPONSE" = "000" ]; then
    echo "❌ Symcon-API nicht erreichbar (Timeout oder Verbindungsfehler)"
    echo "   Prüfen Sie SYMCON_API_URL und ob Symcon läuft"
    ERRORS=$((ERRORS + 1))
else
    echo "⚠️  Symcon-API antwortet mit unerwarteter HTTP-Code: $RESPONSE"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Sicherheit"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check file permissions
PERMS=$(stat -f "%A" .env 2>/dev/null || stat -c "%a" .env 2>/dev/null)
if [ "$PERMS" != "600" ]; then
    echo "⚠️  .env-Datei hat Berechtigung $PERMS (empfohlen: 600)"
    echo "   Setzen mit: chmod 600 .env"
else
    echo "✓ .env Dateiberechtigungen korrekt (600)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  ✓ Validierung erfolgreich!                                       ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║  ✗ Validierung fehlgeschlagen ($ERRORS Fehler)                           ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║  Bitte beheben Sie die oben genannten Fehler.                     ║"
    echo "║  Oder führen Sie erneut aus: ./scripts/setup-env.sh                ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    exit 1
fi
