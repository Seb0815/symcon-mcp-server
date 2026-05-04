# Symcon MCP Server – Docker-basierte Smart Home Integration

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](CHANGELOG.md)
[![Docker](https://img.shields.io/badge/docker-ready-brightgreen.svg)](docs/DOCKER_DEPLOYMENT.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**MCP-Server für IP-Symcon**: Stellt die Symcon JSON-RPC API als MCP-Tools bereit, sodass KI-Clients (Claude, Cursor, eigene Assistenten) Ihr Smart Home steuern können.

**🐳 Neu in v2.0:** Docker-basiertes Deployment – keine Node.js-Installation auf SymBox mehr erforderlich!

---

## 🏗️ Architektur

```
┌─────────────────────────────────────┐
│  KI-Client (Claude, Cursor, etc.)  │
│  → Steuert Smart Home per Sprache   │
└──────────────┬──────────────────────┘
               │ HTTP + Bearer Token
               ↓
┌─────────────────────────────────────┐
│  🐳 Docker Container (PC/Mac/VPS)   │
│  ┌───────────────────────────────┐  │
│  │  MCP Server (Node.js)         │  │
│  │  • Rate Limiting              │  │
│  │  • Audit Logging              │  │
│  │  • Health Checks              │  │
│  └─────────┬─────────────────────┘  │
└────────────┼────────────────────────┘
             │ JSON-RPC (HTTP)
             ↓
┌─────────────────────────────────────┐
│  📦 Symcon Server (SymBox/PC)       │
│  ┌───────────────────────────────┐  │
│  │  IP-Symcon                    │  │
│  │  • JSON-RPC API (Port 3777)   │  │
│  │  • PHP-Modul: MCP Client      │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
             │
             ↓
┌─────────────────────────────────────┐
│  🏠 Smart Home Geräte               │
│  (Hue, Homematic, Shelly, ...)     │
└─────────────────────────────────────┘
```

### Komponenten

| Komponente | Läuft auf | Funktion |
|------------|-----------|----------|
| **MCP Server** | Docker (PC/Mac/VPS) | Übersetzt KI-Anfragen in Symcon-Befehle |
| **PHP-Modul** | SymBox/Symcon | Überwacht Docker-Verbindung, zeigt Status |
| **Symcon API** | SymBox/Symcon | Steuert eigentliche Smart Home Geräte |

---

## 🚀 Quickstart (5 Minuten)

### Voraussetzungen
- **Docker** + **Docker Compose** ([Installation](https://docs.docker.com/get-docker/))
- **IP-Symcon** ab Version 5.0 (läuft auf SymBox/PC)
- Netzwerk-Zugriff: Docker-Host ↔ Symcon-Server

### Installation

#### 1. Docker-Host (PC/Mac) einrichten

```bash
# Repository klonen
git clone https://github.com/beeXperts-Niko/symcon-mcp-server.git
cd symcon-mcp-server

# Konfiguration erstellen (interaktiv)
./scripts/setup-env.sh

# Docker-Image bauen
./build-docker.sh

# Container starten
./start-docker.sh
```

✅ Server läuft jetzt auf `http://localhost:4096`

#### 2. Symcon PHP-Modul installieren (SymBox)

**Option A: Über Symcon Module Control (empfohlen)**
1. Symcon-Weboberfläche → **Module Control**
2. Repository hinzufügen: `https://github.com/beeXperts-Niko/symcon-mcp-server`
3. Instanz erstellen: **MCP Server**

**Option B: Manuelles Deployment**
```bash
# PHP-Modul zur SymBox kopieren
./deploy-to-symbox.sh root@<SymBox-IP>
```

#### 3. Symcon-Modul konfigurieren

1. Symcon-Weboberfläche → **MCP Server**-Modul öffnen
2. Konfiguration:
   - **MCP Server URL:** `http://<DOCKER-HOST-IP>:4096`
     - Gleiche Maschine: `http://localhost:4096`
     - Remote: `http://192.168.1.50:4096`
   - **API-Key:** Aus `.env` kopieren (`MCP_AUTH_TOKEN=...`)
   - **Aktiv:** ✓ Häkchen setzen
3. **Änderungen übernehmen** klicken

✅ Status wird **grün**: "Verbunden mit MCP Server"

#### 4. KI-Client verbinden (z.B. Claude Desktop)

Siehe: [Claude einbinden](docs/CLAUDE_EINBINDEN.md)

---

## 📋 Deployment-Szenarien

### Szenario 1: Alles lokal (einfachste Variante)
```
PC/Mac: Docker + Symcon + Claude
```
- Docker-Host = Symcon-Server = localhost
- `.env`: `SYMCON_API_URL=http://127.0.0.1:3777/api/`
- Symcon-Modul: `MCP Server URL: http://localhost:4096`

### Szenario 2: Docker auf PC, Symcon auf SymBox (Standard)
```
PC: Docker + Claude  ←→  SymBox: Symcon
```
- Docker-Host (PC): `192.168.1.50`
- SymBox: `192.168.1.100`
- `.env`: `SYMCON_API_URL=http://192.168.1.100:3777/api/`
- Symcon-Modul: `MCP Server URL: http://192.168.1.50:4096`

### Szenario 3: Docker im Internet (VPS/Cloud)
```
Heimnetz (SymBox) ←Internet→ VPS (Docker)
```
- Erfordert: VPN/Tunnel oder WebSocket-Bridge
- Siehe: [Architektur Server im Internet](docs/ARCHITEKTUR_SERVER_IM_INTERNET.md)

---

## 🔐 Sicherheit

**Implementierte Maßnahmen:**
- ✅ Verpflichtender API-Key (Server startet nicht ohne)
- ✅ Rate Limiting (100 Requests/min)
- ✅ Audit Logging (alle Tool-Calls)
- ✅ Health-Check-Endpoint
- ✅ Constant-Time Token-Vergleich

**Best Practices:**
```bash
# Sicheren API-Key generieren
openssl rand -hex 32

# File-Permissions setzen
chmod 600 .env

# Firewall (optional, nur localhost)
sudo ufw allow from 127.0.0.1 to any port 4096
```

📖 Mehr: [Sicherheitskonzept](docs/SICHERHEITSKONZEPT.md)

---

## 🛠️ Verwaltung

### Status prüfen
```bash
docker ps | grep symcon-mcp-server
curl http://localhost:4096/health
```

### Logs anzeigen
```bash
docker logs -f symcon-mcp-server

# Nur Security-Warnungen
docker logs symcon-mcp-server | jq 'select(.level=="SECURITY_WARNING")'
```

### Neu starten
```bash
docker-compose restart
```

### Stoppen
```bash
./stop-docker.sh
```

### Updates installieren
```bash
git pull
./build-docker.sh
./start-docker.sh
```

---

## 🧰 MCP-Tools (Auszug)

**Basis-Steuerung:**
- `symcon_get_value` – Variable lesen
- `symcon_set_value` – Variable schreiben
- `symcon_request_action` – Aktion auslösen (Licht, Jalousie, etc.)

**Discovery:**
- `symcon_get_object_tree` – Objektbaum durchsuchen
- `symcon_control_device` – Gerät per Sprache steuern
- `symcon_get_variable_by_path` – Variable per Pfad finden

**Wissensbasis (Sprachsteuerung):**
- `symcon_knowledge_set` – Gerät lernen ("Büro Licht" → variableId)
- `symcon_resolve_device` – Phrase auflösen
- `symcon_snapshot_variables` + `symcon_diff_variables` – Gerät per Vorher/Nachher finden

**Automationen:**
- `symcon_schedule_once` – Einmaliger Timer
- `symcon_script_get_content` – PHP-Skript-Inhalt lesen
- `symcon_script_create` – PHP-Skript erstellen
- `symcon_event_create_cyclic` – Zyklisches Event

📖 Vollständige Liste: [Modulreferenz](docs/MODULREFERENZ.md)

---

## 📚 Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) | Vollständiger Docker-Guide |
| [ANLEITUNG_INSTALLATION.md](ANLEITUNG_INSTALLATION.md) | Schritt-für-Schritt Anleitung |
| [SICHERHEITSKONZEPT.md](docs/SICHERHEITSKONZEPT.md) | Security-Übersicht |
| [CLAUDE_EINBINDEN.md](docs/CLAUDE_EINBINDEN.md) | Claude Desktop Integration |
| [SPRACHASSISTENT_BAUEN.md](docs/SPRACHASSISTENT_BAUEN.md) | Voice-Interface bauen |
| [STEUERUNG_HINWEISE.md](docs/STEUERUNG_HINWEISE.md) | Geräte-spezifische Tipps |
| [AUTOMATIONEN.md](docs/AUTOMATIONEN.md) | Zeitgesteuerte Aktionen |
| [MODULREFERENZ.md](docs/MODULREFERENZ.md) | Alle MCP-Tools |
| [CHANGELOG.md](CHANGELOG.md) | Versionshistorie |

---

## 🔄 Migration von v1.x

Falls Sie eine alte Installation haben:

```bash
./scripts/migrate-from-local.sh
```

Das Script:
- Stoppt alte Node.js-Prozesse
- Sichert Knowledge Store (JSON-Dateien)
- Erstellt `.env` mit migriertem API-Key
- Führt durch das Docker-Setup

---

## 🐛 Troubleshooting

### Container startet nicht
```bash
# Logs prüfen
docker logs symcon-mcp-server

# .env validieren
./scripts/validate-env.sh
```

### Health-Check schlägt fehl
```bash
# MCP_AUTH_TOKEN gesetzt?
grep MCP_AUTH_TOKEN .env

# Port belegt?
lsof -i :4096
```

### Symcon-Modul zeigt "Nicht verbunden"
1. ✅ Container läuft? (`docker ps`)
2. ✅ Health-Check OK? (`curl http://localhost:4096/health`)
3. ✅ MCP Server URL korrekt?
4. ✅ API-Key identisch (.env ↔ Symcon-Modul)?
5. ✅ Firewall blockiert Port 4096?

📖 Mehr: [Docker Deployment Guide](docs/DOCKER_DEPLOYMENT.md#troubleshooting)

---

## 💻 Entwicklung

### Lokaler Build
```bash
cd libs/mcp-server
npm install
npm run build
```

### TypeScript-Code ändern
Nach Änderungen in `src/`:
```bash
npm run build
git add dist/  # Pre-compiled für Git-Installationen
```

### Docker-Image lokal testen
```bash
./build-docker.sh
docker run -it --rm --env-file .env -p 4096:4096 symcon-mcp-server:latest
```

---

## 🤝 Beitragen

Pull Requests willkommen! Bitte beachten:
- **Breaking Changes** → Major-Version (3.0.0)
- **Features** → Minor-Version (2.1.0)
- **Bugfixes** → Patch-Version (2.0.1)

**Wichtige Dateien für PRs:**
- `libs/mcp-server/src/` – TypeScript-Code
- `MCPServer/` – PHP-Modul
- `docs/` – Dokumentation
- `CHANGELOG.md` – Änderungen beschreiben

---

## 📄 Lizenz

MIT License – siehe [LICENSE](LICENSE)

---

## 🙏 Credits

- [@modelcontextprotocol](https://github.com/modelcontextprotocol) für das MCP SDK
- Community für Feedback und Testing
- IP-Symcon für die exzellente Smart Home Platform

---

## ⭐ Support

Bei Fragen oder Problemen:
- [GitHub Issues](https://github.com/beeXperts-Niko/symcon-mcp-server/issues)
- [Dokumentation](docs/)
- Logs prüfen: `docker logs symcon-mcp-server`
