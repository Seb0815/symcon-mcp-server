# Copilot Instructions for symcon-mcp-server

## Projektüberblick (wichtig vor Änderungen)
- Dieses Repo ist **zweigeteilt**: Node-basierter MCP-Server in `libs/mcp-server/` und Symcon-PHP-Modul in `MCPServer/`.
- Das PHP-Modul (`MCPServer/module.php`) startet keinen Node-Prozess mehr; es überwacht nur einen extern laufenden Docker-MCP-Server per `/health`.
- Haupt-Datenfluss: KI-Client → MCP HTTP Endpoint (`libs/mcp-server/src/index.ts`) → `SymconClient` JSON-RPC Calls → IP-Symcon API (`/api/`).
- MCP-Tools sind zentral in `libs/mcp-server/src/tools/index.ts` registriert und dort fachlich beschrieben.

## Kritische Laufzeit- und Sicherheitsannahmen
- `MCP_AUTH_TOKEN` ist **verpflichtend**; ohne Token beendet sich der Server absichtlich beim Start (`src/index.ts`).
- Auth wird nur für `POST` geprüft; `/health` bleibt offen für Monitoring.
- Rate Limiting ist eingebaut (`MCP_RATE_LIMIT`, default 100/min, in `src/index.ts`).
- Persistente Lern-/Automationsdaten liegen standardmäßig in `libs/mcp-server/data/` als JSON (`KnowledgeStore.ts`, `AutomationStore.ts`).

## Arbeitsabläufe (bevorzugte Commands)
- Initiales Setup: `./scripts/setup-env.sh` (erzeugt/aktualisiert `.env`, generiert sicheren API-Key).
- Build Image: `./build-docker.sh`
- Start Container: `./start-docker.sh`
- Stop: `./stop-docker.sh`
- Lokale Entwicklung am TS-Server: in `libs/mcp-server/` `npm run build` und `npm run start`.
- Schneller Laufzeitcheck: `curl http://localhost:4096/health` und `docker logs -f symcon-mcp-server`.

## Code-Konventionen dieses Repos
- Neue Symcon-Funktionen als MCP-Tool immer in `createToolHandlers()` ergänzen (`src/tools/index.ts`) und über `SymconClient` aufrufen.
- Input-Schemas werden mit `zod` definiert; bestehendes Pattern (Schema + `description` + `handler`) beibehalten.
- Sensible Tools (z. B. Skript-Erstellung/-Ausführung) laufen über Audit-Wrapper; diese Logik nicht umgehen.
- Für Geräte-Schaltvorgänge bevorzugt `RequestAction` statt `SetValue` (siehe Tool-Beschreibungen zu Hue/Aktoren).
- Symcon-Endpoint erwartet typischerweise `/api/` mit trailing slash; `SymconClient` normalisiert das bewusst.

## Integrationen und Grenzen
- Docker-Deployment ist der Primärpfad (`docker-compose.yml`, `libs/mcp-server/Dockerfile`).
- `.mcpb` in `mcpb/` ist ein separater Adapter-Launcher (stdio → streamable HTTP), kein Ersatz für den laufenden MCP-Server.
- Symcon-UI-Konfiguration liegt in `MCPServer/form.json`; bei Property-Änderungen auch `module.php` konsistent halten.
- Wenn API-/Konfig-Schlüssel umbenannt werden, Root-Skripte (`start-docker.sh`, `build-docker.sh`, `scripts/setup-env.sh`) mit anpassen.

## Validierung nach Änderungen
- Für TS-Änderungen mindestens `npm run build` in `libs/mcp-server/` ausführen.
- Für Laufzeitänderungen den Docker-Healthcheck und einen echten MCP-Call gegen `/` (POST) prüfen.
- Für PHP-Modul-Änderungen auf funktionierende Form-Aktionen (`MCPServer_TestConnection`) und Statusvariable `ConnectionStatus` achten.