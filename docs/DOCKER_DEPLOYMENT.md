# Docker Deployment - Symcon MCP Server

## Übersicht

Ab Version 2.0 läuft der Symcon MCP Server in einem **Docker-Container** und kommuniziert per HTTP mit dem Symcon-Server. Das PHP-Modul in Symcon ist nur noch ein HTTP-Client, der die Verbindung zum Docker-Container überwacht.

### Architektur

```
┌────────────────────────────────────────┐
│  KI-Client (Claude, Cursor, etc.)     │
│  http://localhost:4096                 │
└──────────────┬─────────────────────────┘
               │ HTTP/Bearer Token
               ↓
┌────────────────────────────────────────┐
│  Docker Container                      │
│  ┌──────────────────────────────────┐  │
│  │  MCP Server (Node.js)            │  │
│  │  Port: 4096                      │  │
│  │  Auth: API-Key (verpflichtend)   │  │
│  └────────┬─────────────────────────┘  │
└───────────┼────────────────────────────┘
            │ HTTP JSON-RPC
            ↓
┌────────────────────────────────────────┐
│  Symcon Server (SymBox/PC)            │
│  ┌──────────────────────────────────┐  │
│  │  JSON-RPC API (Port 3777)        │  │
│  │  PHP-Modul: MCP Client            │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

**Vorteile:**
- ✅ Keine Node.js-Installation auf SymBox erforderlich
- ✅ Sauberes Lifecycle-Management via Docker
- ✅ Einfache Updates (nur Docker-Image neu bauen)
- ✅ Verpflichtende Authentifizierung (sicherer)
- ✅ Rate Limiting & Audit Logging integriert

---

## Voraussetzungen

### System
- **Docker** (Version 20.10+)
- **Docker Compose** (Version 1.29+)
- **Netzwerk-Zugriff** zur SymBox/Symcon-Server

### Installation prüfen
```bash
docker --version
docker-compose --version
```

Falls nicht installiert:
- **macOS/Windows:** [Docker Desktop](https://www.docker.com/products/docker-desktop)
- **Linux:** `sudo apt install docker.io docker-compose` (Debian/Ubuntu)

---

## Quickstart (5 Minuten)

### 1. Repository klonen
```bash
git clone https://github.com/beeXperts-Niko/symcon-mcp-server.git
cd symcon-mcp-server
```

### 2. Konfiguration erstellen
```bash
./scripts/setup-env.sh
```

Das Script fragt interaktiv:
- Symcon-API-URL (z.B. `http://192.168.1.100:3777/api/`)
- Optional: Symcon-Credentials (bei Remote Access)
- Generiert automatisch einen sicheren API-Key

### 3. Docker-Image bauen
```bash
./build-docker.sh
```

### 4. Container starten
```bash
./start-docker.sh
```

### 5. Symcon-Modul konfigurieren
1. In Symcon-Weboberfläche: **MCP Server**-Modul öffnen
2. **MCP Server URL:** `http://localhost:4096` (oder IP des Docker-Hosts)
3. **API-Key:** Aus `.env`-Datei kopieren (`MCP_AUTH_TOKEN=...`)
4. **Aktiv:** Häkchen setzen
5. **Änderungen übernehmen** klicken

✅ Status sollte **grün** werden: "Verbunden mit MCP Server"

---

## Manuelle Konfiguration

### .env-Datei erstellen

Falls Sie `setup-env.sh` nicht verwenden möchten:

```bash
cp .env.example .env
```

Dann bearbeiten:
```bash
# Pflichtfelder
MCP_PORT=4096
MCP_AUTH_TOKEN=<hier-64-zeichen-hex-key>  # Generieren: openssl rand -hex 32
SYMCON_API_URL=http://192.168.1.100:3777/api/

# Optional: Symcon Remote Access Authentifizierung
SYMCON_API_USER=ihre-email@example.com
SYMCON_API_PASSWORD=ihr-passwort

# Optional: Erweiterte Einstellungen
MCP_LOG_LEVEL=info          # error, warn, info, debug
MCP_RATE_LIMIT=100          # Requests pro Minute
```

**Sicherheit:** `.env` niemals in Git committen!
```bash
chmod 600 .env  # Nur Besitzer kann lesen
```

---

## Docker-Befehle

### Container-Status prüfen
```bash
docker ps | grep symcon-mcp-server
```

### Logs anzeigen
```bash
docker logs -f symcon-mcp-server
```

### Container neustarten
```bash
docker-compose restart
```

### Container stoppen
```bash
./stop-docker.sh
# ODER
docker-compose down
```

### Container mit Volumes löschen (⚠️ löscht Knowledge Store!)
```bash
docker-compose down -v
```

### Health-Check manuell prüfen
```bash
curl http://localhost:4096/health
```

Erwartete Antwort:
```json
{
  "status": "ok",
  "version": "2.0.0",
  "authenticated": true,
  "symconApi": "http://192.168.1.100:3777/api/",
  "timestamp": "2026-02-18T10:30:00.000Z"
}
```

---

## Troubleshooting

### Container startet nicht

**Problem:** `docker-compose up -d` schlägt fehl

**Lösung:**
```bash
# 1. Logs prüfen
docker logs symcon-mcp-server

# 2. Validierung der .env
./scripts/validate-env.sh

# 3. Port bereits belegt?
lsof -i :4096  # macOS/Linux
```

### Health-Check schlägt fehl

**Problem:** `curl http://localhost:4096/health` antwortet nicht

**Ursachen:**
1. **Container läuft nicht**
   ```bash
   docker ps -a | grep symcon-mcp
   ```

2. **MCP_AUTH_TOKEN fehlt** (Server startet nicht)
   ```bash
   docker logs symcon-mcp-server | grep "FATAL"
   ```
   → `.env` prüfen, `MCP_AUTH_TOKEN` muss gesetzt sein!

3. **Port-Mapping falsch**
   ```bash
   docker port symcon-mcp-server
   ```

### Symcon-Modul zeigt "Nicht verbunden"

**Checkliste:**
1. ✅ Docker-Container läuft? (`docker ps`)
2. ✅ Health-Check erfolgreich? (`curl http://localhost:4096/health`)
3. ✅ MCP Server URL korrekt? (bei gleicher Maschine: `http://localhost:4096`)
4. ✅ API-Key identisch in `.env` und Symcon-Modul?
5. ✅ Firewall blockiert Port 4096?
6. ✅ Bei Remote-Docker: IP statt `localhost` verwenden!

### Symcon-API nicht erreichbar

**Problem:** Logs zeigen "MCP Server nicht erreichbar: http://127.0.0.1:3777/api/"

**Ursache:** Container kann Symcon-Server nicht erreichen

**Lösung bei lokalem Symcon:**
```yaml
# docker-compose.yml anpassen:
services:
  mcp-server:
    network_mode: "host"  # Container nutzt Host-Netzwerk
```

**Lösung bei Remote-Symcon:**
```bash
# .env anpassen:
SYMCON_API_URL=http://192.168.1.100:3777/api/  # Nicht 127.0.0.1!
```

### Audit-Logs zu viele Einträge

**Problem:** Logs fluten mit DEBUG-Informationen

**Lösung:**
```bash
# .env anpassen:
MCP_LOG_LEVEL=warn  # Nur Warnungen und Fehler
```

---

## Migration von v1.x

Falls Sie bereits eine lokale Node.js-Installation haben:

```bash
./scripts/migrate-from-local.sh
```

Das Script:
1. Stoppt alte Node.js-Prozesse
2. Sichert Knowledge Store (JSON-Dateien)
3. Erstellt `.env` mit migriertem API-Key
4. Führt Sie durch das Setup

---

## Netzwerk-Szenarien

### Szenario 1: Alles auf einer Maschine
```
Docker-Host = Symcon-Server = Localhost
```

```bash
# .env
SYMCON_API_URL=http://127.0.0.1:3777/api/

# Symcon-Modul
MCP Server URL: http://localhost:4096
```

### Szenario 2: Docker auf PC, Symcon auf SymBox
```
PC (Docker) <--Netzwerk--> SymBox (Symcon)
```

```bash
# .env (auf PC)
SYMCON_API_URL=http://192.168.1.100:3777/api/  # SymBox-IP

# Symcon-Modul (auf SymBox)
MCP Server URL: http://192.168.1.50:4096  # PC-IP
```

### Szenario 3: Docker im Internet (VPS)
```
Heimnetz (Symcon) <--Internet--> VPS (Docker)
```

**Nicht empfohlen ohne:**
- VPN oder Tunnel (Tailscale, WireGuard)
- Reverse Proxy mit Let's Encrypt (Caddy/Traefik)
- Firewall-Regeln

Siehe: [ARCHITEKTUR_SERVER_IM_INTERNET.md](ARCHITEKTUR_SERVER_IM_INTERNET.md)

---

## Performance-Tuning

### Rate Limiting anpassen
```bash
# .env
MCP_RATE_LIMIT=200  # Mehr Requests pro Minute erlauben
```

### Log-Verbosity reduzieren
```bash
# .env
MCP_LOG_LEVEL=warn  # Nur Warnungen und Fehler
```

### Docker-Ressourcen begrenzen
```yaml
# docker-compose.yml
services:
  mcp-server:
    deploy:
      resources:
        limits:
          cpus: '0.5'      # Maximal 50% einer CPU
          memory: 256M     # Maximal 256 MB RAM
```

---

## Sicherheit

### Empfohlene Maßnahmen

1. **API-Key sicher generieren**
   ```bash
   openssl rand -hex 32  # Mindestens 32 Bytes (64 Hex-Zeichen)
   ```

2. **File-Permissions prüfen**
   ```bash
   chmod 600 .env
   ls -la .env  # Sollte: -rw------- zeigen
   ```

3. **Firewall konfigurieren**
   ```bash
   # Nur localhost erlauben (wenn möglich)
   sudo ufw allow from 127.0.0.1 to any port 4096
   ```

4. **HTTPS verwenden** (bei Internet-Zugriff)
   - Reverse Proxy mit Let's Encrypt (siehe unten)

5. **Regelmäßige Updates**
   ```bash
   git pull
   ./build-docker.sh
   docker-compose up -d
   ```

### Docker Secrets (erweitert)

Für Production-Umgebungen mit mehreren Usern:

Siehe: [DOCKER_SECRETS.md](DOCKER_SECRETS.md)

---

## Updates

### Neue Version installieren

```bash
# 1. Repository aktualisieren
git pull

# 2. Container stoppen
./stop-docker.sh

# 3. Neu bauen
./build-docker.sh

# 4. Neu starten
./start-docker.sh

# 5. Prüfen
curl http://localhost:4096/health
```

**Knowledge Store bleibt erhalten** (liegt in `libs/mcp-server/data/`!)

---

## Weitere Dokumentation

- [Sicherheitskonzept](SICHERHEITSKONZEPT.md)
- [Docker Secrets](DOCKER_SECRETS.md)
- [Internet-Server-Architektur](ARCHITEKTUR_SERVER_IM_INTERNET.md)
- [Modulreferenz](MODULREFERENZ.md)
- [Sprachassistent bauen](SPRACHASSISTENT_BAUEN.md)

---

## Support

Bei Problemen:
1. [GitHub Issues](https://github.com/beeXperts-Niko/symcon-mcp-server/issues)
2. Docker-Logs prüfen: `docker logs symcon-mcp-server`
3. `.env` validieren: `./scripts/validate-env.sh`
