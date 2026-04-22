# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

---

## [2.1.0] - 2026-04-22

### 🔒 Sicherheit

#### Konfigurierbare Tool-Zugriffsbeschränkung (Access Control)

- **Standard ist jetzt `read-only`**
  - Neue Deployments exponieren standardmäßig nur Lese-Tools
  - KI-Client kann Geräte, Variablen und Objektbaum abfragen, aber keine Aktionen auslösen
  - Schreib-/Steuerungstools müssen explizit freigeschaltet werden

- **Neue Umgebungsvariable `MCP_ACCESS_MODE`**
  - `read-only` (Standard) – nur 16 Lese-Tools aktiv
  - `full` – alle ~42 Tools aktiv
  - `custom` – Kategorien einzeln per Flag freischalten

- **Kategorie-Flags (wirksam in `custom`-Modus)**
  - `MCP_ALLOW_CONTROL=true` – Gerätsteuerung (`request_action`, `set_value`, `control_device`, `schedule_once`)
  - `MCP_ALLOW_KNOWLEDGE_WRITE=true` – Wissensbasis schreiben (Gerätezuordnungen lernen)
  - `MCP_ALLOW_AUTOMATION=true` – Skripte & Events erstellen/ausführen/löschen

- **Feinsteuerung auf Tool-Ebene**
  - `MCP_TOOL_WHITELIST` – kommagetrennte Tool-Namen explizit erlauben (höchste Priorität)
  - `MCP_TOOL_BLACKLIST` – kommagetrennte Tool-Namen explizit sperren (wird zuletzt angewendet)

- **Startup-Logging** – beim Start werden aktive und blockierte Tools in `docker logs` ausgegeben

### ⚠️ BREAKING CHANGE für bestehende Deployments

Wer bisher **alle Tools** (insbesondere Gerätesteuerung) genutzt hat, muss nach dem Update setzen:

```env
MCP_ACCESS_MODE=full
```

Andernfalls sind nach dem Update nur Lese-Tools verfügbar.

### 📝 Dokumentation

- `ANLEITUNG_INSTALLATION.md` – neuer Abschnitt „Schritt 5a: Zugriffs-Beschränkung"
- `ANLEITUNG_INSTALLATION.md` – `X-MCP-API-Key`-Header-Format klargestellt: kein `Bearer`-Präfix
- `ANLEITUNG_INSTALLATION.md` – Docker-Log-Befehle ergänzt (`docker logs` und `docker compose logs`)
- `ANLEITUNG_INSTALLATION.md` – OpenWebUI/Halluzinations-Troubleshooting + Schnelltest-curl ergänzt
- `local-config.env.example` – Access-Control-Abschnitt mit allen Vars und Kommentaren ergänzt
- `.env.example` erstellt (fehlte bisher; Basis-Template für `scripts/setup-env.sh`)
- `scripts/setup-env.sh` – interaktiver Prompt für `MCP_ACCESS_MODE` bei der Ersteinrichtung

### 🐛 Bugfixes

- `start-docker.sh` legt `libs/mcp-server/data/` automatisch an — Volume-Mount schlug bei frischem Clone fehl

---

## [2.0.0] - 2026-02-18

### 🚀 BREAKING CHANGES

#### Docker-basiertes Deployment
- **MCP Server läuft jetzt in Docker-Container**
  - Node.js-Installation auf SymBox nicht mehr erforderlich
  - PHP-Modul ist jetzt HTTP-Client (kein Prozess-Management mehr)
  - Eigenständiges Lifecycle-Management via Docker Compose

#### Verpflichtende Authentifizierung
- **API-Key ist jetzt PFLICHT**
  - Server startet nicht ohne `MCP_AUTH_TOKEN` in `.env`
  - Klare Fehlermeldung mit Setup-Anleitung bei fehlendem Key
  - Erhöht Sicherheit massiv (kein versehentlich offener Server mehr)

#### Neue Konfiguration
- **`.env`-Datei ersetzt alte Config-Parameter**
  - Port, Symcon-API-URL, API-Key, etc. zentral in `.env`
  - PHP-Modul speichert nur noch:
    - MCP Server URL (z.B. `http://localhost:4096`)
    - API-Key (für Connection-Check)
    - Active-Status

### ✨ Neue Features

#### Sicherheit
- **Rate Limiting** (100 Requests/Minute per IP, konfigurierbar)
  - Verhindert DoS-Angriffe und Brute-Force
  - HTTP 429 Response mit `Retry-After` Header
  
- **Audit Logging** (JSON-Format nach stderr)
  - Alle Tool-Calls werden protokolliert
  - Security-Warnungen für kritische Tools (`symcon_script_*`)
  - Konfigurierbare Log-Level (`error`, `warn`, `info`, `debug`)

- **Health-Check-Endpoint** (`GET /health`)
  - Status, Version, Authenticated-Flag, Symcon-API-URL
  - Für Docker Health-Checks und Monitoring

#### Developer Experience
- **Interaktive Setup-Scripts**
  - `./scripts/setup-env.sh` - Guided Setup mit Validierung
  - `./scripts/validate-env.sh` - .env-Datei prüfen
  - `./scripts/migrate-from-local.sh` - Migration von v1.x

- **Docker-Scripts**
  - `./build-docker.sh` - TypeScript Build + Docker Image
  - `./start-docker.sh` - Container starten mit Health-Check
  - `./stop-docker.sh` - Container stoppen (optional mit Volume-Cleanup)

#### Dokumentation
- **Umfassende Docs**
  - [docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) - Vollständiger Docker-Guide
  - [docs/SICHERHEITSKONZEPT.md](docs/SICHERHEITSKONZEPT.md) - Security-Übersicht
  - [docs/DOCKER_SECRETS.md](docs/DOCKER_SECRETS.md) - Migration zu Secrets (optional)

### 🔧 Änderungen

#### MCP Server
- Version aus `package.json` wird dynamisch geladen (zuvor hardcoded)
- Schönere Konsolen-Ausgabe mit Box-Drawing-Characters
- Constant-Time-Vergleich für API-Keys (Timing-Attack-Protection)

#### PHP-Modul
- **Komplett umgebaut**
  - Entfernt: Process-Management, PID-Files, `proc_open`
  - Neu: HTTP-Client, Health-Check, Connection-Timer
  - Status-Variable zeigt Verbindung (grün/rot in Symcon-UI)

- **Neue Modul-Properties**
  - `MCPServerURL` (ersetzt `Port`)
  - `ApiKey` (weiterhin, aber nur für Connection-Check)
  - Entfernt: `SymconApiUrl` (wird vom Docker-Container verwaltet)

- **Neue Public Methods**
  - `CheckConnection()` - Verbindungstest
  - `GetAPIKey()` - API-Key zurückgeben
  - `TestConnection()` - Human-readable Test-Result

#### Deployment
- `deploy-to-symbox.sh` deployed jetzt nur noch PHP-Modul (nicht Node.js)
- `start-mcp-local.sh` zeigt Deprecation-Warnung (funktioniert aber noch)

### 🐛 Bugfixes
- Float-Normalisierung in SymconClient bleibt erhalten
- Symcon-API-Auth-Header funktioniert weiterhin
- Knowledge Store & Automation Store bleiben kompatibel (JSON-Format)

### 📦 Dependencies
- Keine neuen Runtime-Dependencies
- Docker 20.10+ und Docker Compose 1.29+ als neue System-Requirements

### 🗑️ Deprecations
- **Lokale Node.js-Installation** (via PHP-Modul `proc_open`)
  - Funktioniert noch in v2.0, wird in v3.0 entfernt
  - Migration-Script vorhanden: `./scripts/migrate-from-local.sh`
  
- **Old Property Names** (PHP-Modul)
  - `Port` → `MCPServerURL`
  - `SymconApiUrl` → nicht mehr im Modul (in .env)

### 🔐 Sicherheit
- **CVE-2024-XXXXX: Ungeschützter MCP Server** (behoben)
  - Zuvor: Server konnte ohne Auth laufen (wenn Key leer)
  - Jetzt: Server terminiert wenn Key fehlt
  
- **Rate Limiting schützt vor DoS/Brute-Force**
- **Audit Logging erhöht Nachvollziehbarkeit**

### 📝 Migration-Guide

#### Von v1.x auf v2.0

1. **Backup erstellen**
   ```bash
   cp -r libs/mcp-server/data libs/mcp-server/data.backup
   ```

2. **Migration-Script ausführen**
   ```bash
   ./scripts/migrate-from-local.sh
   ```

3. **Docker-Setup**
   ```bash
   ./build-docker.sh
   ./start-docker.sh
   ```

4. **Symcon-Modul anpassen**
   - MCP Server URL: `http://localhost:4096`
   - API-Key aus `.env` kopieren
   - "Änderungen übernehmen"

5. **Prüfen**
   - Status-Variable sollte grün werden
   - Health-Check: `curl http://localhost:4096/health`

**Knowledge Store bleibt erhalten!** (JSON-Dateien in `libs/mcp-server/data/`)

---

## [1.3.12] - 2024-XX-XX

### Features
- MCP Tools für Symcon-API
- Knowledge Store für Sprachsteuerung
- Automation Store für geplante Aktionen
- PHP-Modul mit Process-Management
- Lokale Node.js-Installation

### Known Issues
- Node.js muss auf SymBox installiert sein (oft nicht der Fall)
- Keine verpflichtende Authentifizierung
- Kein Rate Limiting
- Process-Management fragil (PID-Files)

---

## Versionsschema

- **Major (X.0.0)**: Breaking Changes (z.B. Docker-Migration)
- **Minor (2.X.0)**: Neue Features (rückwärtskompatibel)
- **Patch (2.0.X)**: Bugfixes und kleinere Verbesserungen

---

## Links

- [GitHub Releases](https://github.com/beeXperts-Niko/symcon-mcp-server/releases)
- [Docker Hub](https://hub.docker.com/r/beexperts/symcon-mcp-server) (falls deployed)
- [Documentation](docs/)
