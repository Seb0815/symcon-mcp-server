# PR-Readiness: Docker-Migration v2.0.0

Dieses Dokument erklärt die Architektur und Deployment-Struktur für Pull Requests.

## 🎯 Architektur-Übersicht

### Was läuft wo?

#### 1. Docker-Host (PC/Mac/VPS)
**Was wird deployed:**
- Komplettes Repository klonen
- Docker-Container bauen und starten
- `.env`-Datei mit Konfiguration

**Dateien:**
```
symcon-mcp-server/
├── .env                          # Konfiguration (NICHT committen!)
├── docker-compose.yml            # Container-Definition
├── build-docker.sh               # Build-Script
├── start-docker.sh               # Start-Script
├── stop-docker.sh                # Stop-Script
└── libs/mcp-server/
    ├── Dockerfile                # Multi-stage Build
    ├── .dockerignore             # Exclude-Liste
    ├── package.json              # Dependencies
    ├── tsconfig.json             # TypeScript-Config
    ├── src/                      # TypeScript-Source
    │   ├── index.ts              # MCP-Server (gehärtet)
    │   ├── symcon/SymconClient.ts
    │   ├── tools/index.ts        # MCP-Tools + Audit Logging
    │   └── knowledge/            # Knowledge/Automation Store
    └── dist/                     # Kompilierter Code (committed!)
```

**Prozess:**
```bash
./scripts/setup-env.sh   # .env erstellen
./build-docker.sh        # TypeScript → Docker Image
./start-docker.sh        # Container starten → http://localhost:4096
```

---

#### 2. SymBox/Symcon-Server
**Was wird deployed:**
- Nur das PHP-Modul (MCPServer/)
- Keine Node.js-Dateien!
- Modul registriert sich über library.json

**Dateien:**
```
symcon-mcp-server/
├── library.json                  # Modul-Metadaten (Version 2.0.0)
└── MCPServer/
    ├── module.json               # Modul-Definition
    ├── module.php                # HTTP-Client (KEIN proc_open mehr!)
    ├── form.json                 # Symcon-UI (neue Felder)
    ├── locale/
    │   ├── de.json               # Deutsche Texte
    │   └── en.json               # Englische Texte
    └── docs/
        └── README.md             # Modul-Dokumentation
```

**Deployment-Methoden:**

**A. Via Symcon Module Control (Standard)**
1. Repository-URL in Symcon eintragen
2. Symcon lädt automatisch herunter
3. PHP-Modul wird in `/modules/` installiert

**B. Manuell via SSH**
```bash
./deploy-to-symbox.sh root@<SymBox-IP>
```
Kopiert nur `MCPServer/` nach `/var/lib/symcon/modules/MCPServer/`

---

### Kommunikationsfluss

```
1. Claude/Cursor (KI-Client)
   ↓ HTTP POST mit Bearer Token
   
2. Docker-Container (Docker-Host)
   libs/mcp-server/src/index.ts
   - Authentifizierung prüfen
   - Rate Limiting
   - Audit Logging
   ↓ JSON-RPC HTTP Request
   
3. Symcon JSON-RPC API (SymBox)
   Port 3777/api/
   ↓ PHP-Call
   
4. IP-Symcon Core (SymBox)
   PHP-Modul MCPServer/module.php
   - Verbindungsstatus zu Docker prüfen
   - Status-Variable updaten
   
5. Smart Home Geräte
   Hue, Homematic, Shelly, etc.
```

---

## 📦 Deployment-Anleitung für Nutzer

### Setup für PR-Tester

#### Schritt 1: Docker-Host vorbereiten

```bash
# Repository klonen
git clone https://github.com/beeXperts-Niko/symcon-mcp-server.git
cd symcon-mcp-server

# .env erstellen
./scripts/setup-env.sh
# Folgt interaktivem Setup:
# - Symcon-API-URL: http://192.168.1.100:3777/api/
# - Generiert API-Key automatisch

# Docker bauen & starten
./build-docker.sh
./start-docker.sh

# Prüfen
curl http://localhost:4096/health
# Sollte zeigen: {"status":"ok","version":"2.0.0",...}
```

#### Schritt 2: PHP-Modul in Symcon installieren

**Via Module Control:**
1. Symcon → Module Control
2. Repository: `https://github.com/beeXperts-Niko/symcon-mcp-server`
3. Instanz erstellen: "MCP Server"

**Konfiguration in Symcon:**
- **MCP Server URL:** `http://192.168.1.50:4096` (Docker-Host-IP)
- **API-Key:** Aus `.env` kopieren (MCP_AUTH_TOKEN Wert)
- **Aktiv:** ✓ Häkchen setzen
- "Änderungen übernehmen" klicken

✅ Status-Variable wird grün: "Verbunden mit MCP Server"

---

## 🔍 Wichtige Änderungen für PRs

### Breaking Changes
1. **PHP-Modul ist jetzt HTTP-Client**
   - Alte Properties entfernt: `Port`, `SymconApiUrl` (werden im Docker verwaltet)
   - Neue Properties: `MCPServerURL`, `ApiKey`
   - Kein `proc_open` mehr (Prozess-Management entfernt)

2. **MCP-Server läuft in Docker**
   - Node.js auf SymBox nicht mehr erforderlich
   - Konfiguration über `.env` statt PHP-Properties

3. **Verpflichtender API-Key**
   - Server startet NICHT ohne `MCP_AUTH_TOKEN` in `.env`
   - Sicherheit: Constant-Time-Vergleich, Rate Limiting

### Neue Features
- Rate Limiting (100 req/min)
- Audit Logging (JSON nach stderr)
- Health-Check-Endpoint (`/health`)
- Migration-Script für v1.x-Nutzer
- Umfangreiche Dokumentation (Docker, Security)

### Datei-Änderungen

**Erstellt:**
- `docker-compose.yml`
- `libs/mcp-server/Dockerfile`
- `libs/mcp-server/.dockerignore`
- `.env.example`
- `build-docker.sh`, `start-docker.sh`, `stop-docker.sh`
- `scripts/setup-env.sh`, `scripts/validate-env.sh`, `scripts/migrate-from-local.sh`
- `docs/DOCKER_DEPLOYMENT.md`
- `docs/SICHERHEITSKONZEPT.md`
- `CHANGELOG.md`

**Geändert:**
- `README.md` - Komplett neu für Docker
- `MCPServer/module.php` - Komplett umgebaut (HTTP-Client)
- `MCPServer/form.json` - Neue UI-Felder
- `MCPServer/locale/*.json` - Aktualisierte Texte
- `libs/mcp-server/src/index.ts` - Verpflichtender API-Key, Health-Check, Rate Limiting
- `libs/mcp-server/src/tools/index.ts` - Audit Logging
- `library.json` - Version 2.0.0
- `libs/mcp-server/package.json` - Version 2.0.0, neue Scripts
- `deploy-to-symbox.sh` - Nur noch PHP-Modul
- `start-mcp-local.sh` - Deprecation-Warnung

---

## ✅ Tests vor PR

### 1. Docker-Setup
```bash
./scripts/validate-env.sh        # .env validieren
./build-docker.sh                # Build erfolgreich?
./start-docker.sh                # Container startet?
curl http://localhost:4096/health  # Health-Check OK?
```

### 2. TypeScript-Build
```bash
cd libs/mcp-server
npm install
npm run build                    # Keine Errors?
ls -la dist/index.js             # Datei existiert?
```

### 3. Symcon-Integration
- PHP-Modul installieren (Module Control)
- Konfiguration: MCP Server URL eintragen
- API-Key aus .env kopieren
- Status-Variable wird grün?
- Connection-Check funktioniert?

### 4. MCP-Tools
- Claude/Cursor verbinden
- Tool `symcon_ping` ausführen
- Logs prüfen: `docker logs symcon-mcp-server`
- Audit-Log zeigt Tool-Call?

### 5. Security
- Start ohne MCP_AUTH_TOKEN → Server terminiert?
- 101 Requests in 60s → 429 Error?
- Audit-Log zeigt Security-Warnung bei `symcon_script_create`?

---

## 📝 PR-Checkliste

### Code
- [ ] TypeScript kompiliert ohne Errors
- [ ] `dist/` ist committed (für Git-Installationen!)
- [ ] Docker-Image baut erfolgreich
- [ ] Health-Check funktioniert
- [ ] Rate Limiting funktioniert
- [ ] Audit Logging funktioniert

### Symcon-Integration
- [ ] PHP-Modul lädt ohne Fehler
- [ ] UI zeigt korrekt (form.json)
- [ ] Connection-Check funktioniert
- [ ] Status-Variable updated
- [ ] Locale-Dateien vollständig (de+en)

### Dokumentation
- [ ] README.md aktualisiert (Docker-First)
- [ ] CHANGELOG.md Version 2.0.0 dokumentiert
- [ ] docs/DOCKER_DEPLOYMENT.md vollständig
- [ ] docs/SICHERHEITSKONZEPT.md erstellt
- [ ] Migration-Guide für v1.x vorhanden

### Scripts
- [ ] Alle `.sh`-Dateien sind executable
- [ ] `setup-env.sh` funktioniert
- [ ] `build-docker.sh` funktioniert
- [ ] `start-docker.sh` funktioniert
- [ ] `migrate-from-local.sh` funktioniert
- [ ] `validate-env.sh` zeigt Fehler korrekt

### Sicherheit
- [ ] API-Key ist verpflichtend
- [ ] Constant-Time-Vergleich verwendet
- [ ] `.env` ist in .gitignore
- [ ] Keine Secrets im Repository
- [ ] Security-Warnungen dokumentiert

---

## 🚀 Nach dem Merge

### Für Nutzer kommunizieren:
1. **Breaking Change:** v2.0 erfordert Docker
2. **Migration:** `./scripts/migrate-from-local.sh` ausführen
3. **Dokumentation:** [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) lesen
4. **Community:** GitHub Discussions für Fragen

### Release-Process:
1. Git Tag: `git tag -a v2.0.0 -m "Docker-Migration"`
2. GitHub Release erstellen
3. CHANGELOG.md verlinken
4. Docker Hub (optional): Image pushen

---

## 📞 Support während PR-Review

Bei Fragen zur Architektur:
- **Docker-Fragen:** Siehe [docs/DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md)
- **Symcon-Fragen:** Siehe [MCPServer/docs/README.md](MCPServer/docs/README.md)
- **Security-Fragen:** Siehe [docs/SICHERHEITSKONZEPT.md](docs/SICHERHEITSKONZEPT.md)
