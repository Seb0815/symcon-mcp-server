# Sicherheitskonzept - Symcon MCP Server

## Übersicht

Dieses Dokument beschreibt die Sicherheitsmaßnahmen, bekannte Risiken und Best Practices für den Symcon MCP Server ab Version 2.0.

---

## Implementierte Sicherheitsmaßnahmen

### 1. Verpflichtende Authentifizierung

**Ab Version 2.0**: Der Server startet **nicht** ohne API-Key!

#### Implementierung
- ENV-Variable `MCP_AUTH_TOKEN` ist **verpflichtend**
- Server terminiert mit Exit-Code 1 wenn leer
- Klare Fehlermeldung mit Setup-Anleitung

#### API-Key-Prüfung
```typescript
// Constant-time comparison (verhindert Timing-Angriffe)
function isAuthorized(req: IncomingMessage): boolean {
  const authHeader = req.headers.authorization;
  const apiKeyHeader = req.headers['x-mcp-api-key'];
  
  const bearer = authHeader?.startsWith('Bearer ') 
    ? authHeader.slice(7).trim() 
    : '';
  const key = apiKeyHeader?.toString().trim() || '';
  
  return constantTimeEqual(bearer, MCP_AUTH_TOKEN) 
      || constantTimeEqual(key, MCP_AUTH_TOKEN);
}
```

**Unterstützte Header:**
- `Authorization: Bearer <token>`
- `X-MCP-API-Key: <token>`

**Empfohlene Key-Länge:** 64 Zeichen (32 Bytes Hex)

```bash
# Sicheren Key generieren:
openssl rand -hex 32
```

---

### 2. Rate Limiting

**Ziel:** DoS-Angriffe und Brute-Force verhindern

#### Konfiguration
```bash
# .env
MCP_RATE_LIMIT=100  # Requests pro Minute pro IP
```

#### Implementierung
- In-Memory Map (IP → Request-Count)
- Rolling Window (60 Sekunden)
- HTTP 429 "Too Many Requests" bei Überschreitung
- `Retry-After` Header mit Sekunden bis Reset

#### Beispiel-Response
```http
HTTP/1.1 429 Too Many Requests
Retry-After: 45
X-RateLimit-Limit: 100
X-RateLimit-Reset: 45

{
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Maximum 100 requests per minute.",
  "retryAfter": 45
}
```

**Limitation:** Rate Limiting ist pro Container-Instanz. Bei Container-Restart wird der Counter zurückgesetzt.

---

### 3. Audit Logging

**Ziel:** Nachvollziehbarkeit aller Tool-Aufrufe

#### Was wird geloggt?
- **Alle Tool-Calls** mit Timestamp
- Arguments (nur in DEBUG-Level)
- Result oder Error
- Dauer in Millisekunden

#### Beispiel-Log-Eintrag
```json
{
  "timestamp": "2026-02-18T10:30:00.123Z",
  "toolName": "symcon_set_value",
  "args": "[redacted]",  // Debug-Level zeigt echte Werte
  "result": "[success]",
  "duration": 45
}
```

#### Security-Warnungen
Tools mit Code-Execution-Risiko werden besonders markiert:
```json
{
  "timestamp": "2026-02-18T10:30:00.123Z",
  "level": "SECURITY_WARNING",
  "toolName": "symcon_script_create",
  "message": "Executing tool that allows code execution or script modification"
}
```

#### Log-Level konfigurieren
```bash
# .env
MCP_LOG_LEVEL=info  # error, warn, info, debug
```

- `error`: Nur Fehler
- `warn`: Fehler + Warnungen
- `info`: + Security-Warnungen + Errors (Standard)
- `debug`: + Alle Tool-Calls mit vollen Arguments (⚠️ ggf. sensible Daten!)

#### Logs auslesen
```bash
# Docker
docker logs -f symcon-mcp-server

# JSON-Parsing
docker logs symcon-mcp-server | jq 'select(.level=="SECURITY_WARNING")'
```

---

### 4. Input-Validierung

**Ziel:** Injection-Angriffe verhindern

#### Zod Schema Validation
Alle Tool-Parameter werden validiert:

```typescript
const setValueSchema = z.object({
  variableId: z.number().int().positive(),  // Muss positiver Integer sein
  value: z.union([z.string(), z.number(), z.boolean()])
});
```

**Bei Validation-Fehler:**
- Tool-Call wird abgelehnt
- Fehler wird zurückgegeben (nicht ausgeführt)
- Audit-Log enthält Fehler

#### Bekannte Lücke: PHP-Code-Injection

⚠️ **KRITISCH:** Tools wie `symcon_script_create` und `symcon_script_set_content` erlauben **beliebigen PHP-Code**!

**Risiko:**
```typescript
// KI könnte theoretisch ausführen:
{
  "toolName": "symcon_script_create",
  "args": {
    "name": "Malicious",
    "content": "<?php system('rm -rf /'); ?>"
  }
}
```

**Aktueller Schutz:**
1. Security-Warnung im Audit-Log
2. Dokumentation warnt vor Risiko

**Empfohlene Maßnahmen:**
- Tool-ACLs implementieren (Roadmap)
- Whitelist für erlaubte PHP-Funktionen
- Sandboxing für Skripte (Symcon-Feature)
- User-Bestätigung vor Script-Creation (UI-Layer, nicht MCP-Scope)

---

## Bekannte Risiken

### 1. ENV-Variablen in .env-Datei

**Problem:**
- `.env` liegt im Filesystem (bei Docker-Host)
- Lesbar für jeden User mit Zugriff auf die Datei
- `ps aux` zeigt ENV-Variablen von Child-Processes (minimiert in v2.0)

**Aktueller Schutz:**
```bash
chmod 600 .env  # Nur Besitzer kann lesen
```

**Bessere Lösung (Roadmap):**
- Docker Secrets (siehe [DOCKER_SECRETS.md](DOCKER_SECRETS.md))
- Vault/Kubernetes Secrets

**Empfehlung für v2.0:**
- `.env` niemals in Git committen (✅ bereits in .gitignore)
- File-Permissions auf 600 setzen (✅ setup-env.sh macht das)
- Server/VM-Zugriff beschränken

---

### 2. HTTP statt HTTPS

**Problem:**
- Standard-Setup nutzt HTTP (kein TLS)
- Traffic ist im Netzwerk sichtbar (MitM-Risiko)
- API-Key wird unverschlüsselt übertragen

**Aktueller Schutz:**
- Self-Signed Certificates möglich (aber problematisch für Clients)

**Wann ist HTTP akzeptabel?**
- Lokales Netzwerk (127.0.0.1 oder trusted LAN)
- Hinter Reverse Proxy mit TLS-Termination
- Docker auf gleicher Maschine wie Symcon

**HTTPS erforderlich:**
- Internet-Zugriff
- Öffentliche Netzwerke
- Multi-User-Umgebungen

**Lösung (Roadmap):**
- Let's Encrypt via Caddy/Traefik
- Siehe [ARCHITEKTUR_SERVER_IM_INTERNET.md](ARCHITEKTUR_SERVER_IM_INTERNET.md)

---

### 3. Kein Rollen-basierter Zugriff

**Problem:**
- Ein API-Key = volle Rechte auf ALLE Tools
- Kein `read-only` Mode
- Kein User-Management

**Risiko:**
- Kompromittierter Key erlaubt:
  - Alle Geräte steuern
  - Skripte erstellen/löschen
  - Events manipulieren

**Roadmap:**
- Tool-ACLs (z.B. nur `symcon_get_*` erlauben)
- Per-Tool-API-Keys
- OAuth2/OIDC für Multi-User

---

### 4. Knowledge Store Concurrent Access

**Problem:**
- JSON-Dateien sind nicht concurrent-safe
- Race Conditions bei mehreren MCP-Instanzen möglich

**Aktueller Schutz:**
- Single-Container-Setup (Standard)

**Wenn problematisch:**
- Multi-Instance-Deployment mit Load Balancer

**Lösung (Roadmap):**
- SQLite mit WAL-Mode
- Redis/PostgreSQL

---

## Best Practices

### Deployment

#### 1. Docker-Netzwerk isolieren
```yaml
# docker-compose.yml
services:
  mcp-server:
    networks:
      - symcon-net

networks:
  symcon-net:
    driver: bridge
    internal: false  # true = kein Internet-Zugriff für Container
```

#### 2. Resource Limits setzen
```yaml
services:
  mcp-server:
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
```

#### 3. Health-Checks nutzen
```yaml
services:
  mcp-server:
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:4096/health || exit 1"]
      interval: 30s
      retries: 3
```

#### 4. Logs rotieren
```yaml
services:
  mcp-server:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

### Netzwerk

#### 1. Firewall konfigurieren

**Nur localhost:**
```bash
# UFW (Ubuntu)
sudo ufw allow from 127.0.0.1 to any port 4096

# iptables
sudo iptables -A INPUT -p tcp --dport 4096 -s 127.0.0.1 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 4096 -j DROP
```

**LAN + localhost:**
```bash
sudo ufw allow from 192.168.0.0/16 to any port 4096
sudo ufw allow from 127.0.0.1 to any port 4096
```

#### 2. Reverse Proxy (Production)

**Caddy (empfohlen):**
```
mcp.example.com {
    reverse_proxy localhost:4096
    # Let's Encrypt automatisch
}
```

**Traefik:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.mcp.rule=Host(`mcp.example.com`)"
  - "traefik.http.routers.mcp.tls.certresolver=letsencrypt"
```

---

### Monitoring

#### 1. Health-Checks automatisieren
```bash
# Cron-Job (alle 5 Min.)
*/5 * * * * curl -sf http://localhost:4096/health || systemctl restart docker-compose@symcon-mcp-server
```

#### 2. Audit-Logs analysieren
```bash
# Security-Warnungen filtern
docker logs symcon-mcp-server | jq 'select(.level=="SECURITY_WARNING")' > security.log

# Fehler zählen
docker logs symcon-mcp-server | jq 'select(.error)' | wc -l
```

#### 3. Rate-Limit-Verstöße tracken
```bash
docker logs symcon-mcp-server | grep "429" | wc -l
```

---

## Roadmap

### Kurzfristig (v2.1)
- [ ] Docker Secrets Support
- [ ] Tool-ACLs (read-only Mode)
- [ ] Regex-Blacklist für PHP-Code (gefährliche Funktionen)

### Mittelfristig (v2.2)
- [ ] OAuth2/OIDC Integration
- [ ] Per-Tool-API-Keys
- [ ] SQLite statt JSON (concurrent-safe)

### Langfristig (v3.0)
- [ ] Multi-User-Management
- [ ] Web-UI für Audit-Logs
- [ ] mTLS (Client-Zertifikate)

---

## Security Scorecard

| Kriterium | Status | Bewertung |
|-----------|--------|-----------|
| **Authentifizierung** | Verpflichtend (API-Key) | ✅ Gut |
| **Autorisierung** | Keine (alle Tools) | ⚠️ Mittel |
| **Verschlüsselung** | HTTP (optional HTTPS) | ⚠️ Mittel |
| **Input Validation** | Zod (außer PHP-Code) | ✅ Gut |
| **Secrets Management** | .env (Filesystem) | ⚠️ Mittel |
| **Rate Limiting** | 100/min per IP | ✅ Gut |
| **Audit Logging** | JSON nach stderr | ✅ Gut |
| **Code Injection** | Warnung (keine Prevention) | ❌ Schlecht |
| **Network Security** | Firewall-abhängig | ⚠️ Mittel |

**Gesamt:** ✅ **Gut für Home-Automation, Verbesserungen für Enterprise nötig**

---

## Meldung von Sicherheitslücken

Bitte **nicht** öffentlich via GitHub Issues!

**Kontakt:**
- E-Mail: [Siehe Repo-Owner]
- Encrypted: PGP-Key auf Anfrage

**Responsible Disclosure:**
- Fix innerhalb 30 Tage angestrebt
- Full Disclosure nach Fix + 7 Tage

---

## Danksagungen

- @modelcontextprotocol für das SDK
- Community für Feedback und Testing
