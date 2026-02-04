# Symcon-Smart-Home in Claude einbinden

So nutzt du dein Symcon-Smart-Home **mit Claude** (Anthropic): MCP-Server verbinden + Anweisungen für „erster Überblick“ und interaktives Reden.

---

## „Ziehe .MCPB- oder .DXT-Dateien hier her“ – was bedeutet das?

In Claude Desktop siehst du unter **Einstellungen → Erweiterungen** oft: **„Ziehe .MCPB- oder .DXT-Dateien hier her, um sie zu installieren.“**

- **.mcpb / .dxt** = vorgepackte Erweiterungen (ein Klick, alles drin). Unser Symcon-Server ist aber ein **Streamable-HTTP-Server unter einer URL** (z. B. http://127.0.0.1:4096), **keine** .mcpb-Datei.

**Zwei Wege, den Symcon-Server trotzdem in Claude zu nutzen:**

---

## 1. MCP-Server in Claude verbinden

### Variante A: Config-Datei (empfohlen, wenn nur „.mcpb ziehen“ sichtbar ist)

Claude Desktop kann MCP-Server auch über eine **Konfigurationsdatei** laden. Dafür brauchst du einen kleinen **Adapter**, der zwischen Claude (stdio) und unserem Server (Streamable HTTP per URL) vermittelt.

1. **Symcon MCP-Server starten** (lokal auf dem Mac):
   ```bash
   cd symcon-mcp-server
   ./start-mcp-local.sh
   ```
   Passwort eingeben. Server läuft auf **http://127.0.0.1:4096**.

2. **Config-Datei bearbeiten:**
   - **macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`
   - **Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

   Falls die Datei noch nicht existiert: anlegen. Inhalt (oder als `mcpServers`-Block zu bestehendem Config hinzufügen):

   ```json
   {
     "mcpServers": {
       "symcon": {
         "command": "npx",
         "args": ["-y", "@pyroprompts/mcp-stdio-to-streamable-http-adapter"],
         "env": {
           "URI": "http://127.0.0.1:4096",
           "MCP_NAME": "symcon"
         }
       }
     }
   }
   ```

   Bei MCP-API-Key (falls du einen gesetzt hast):
   ```json
   "env": {
     "URI": "http://127.0.0.1:4096",
     "MCP_NAME": "symcon",
     "BEARER_TOKEN": "DEIN_API_KEY"
   }
   ```

3. **Claude Desktop vollständig neu starten** (nicht nur Fenster schließen). Danach sollte der Symcon-Server als MCP verfügbar sein.

Der Adapter (`@pyroprompts/mcp-stdio-to-streamable-http-adapter`) läuft lokal und leitet alle Aufrufe an deinen Symcon-Server (die URL) weiter. **npx** lädt ihn bei Bedarf automatisch herunter.

---

### Variante B: In Claude eine „URL“ oder „Connector“-Option

Falls in deiner Claude-Version unter **Einstellungen** ein Bereich **„Connectors“**, **„MCP“** oder **„Server hinzufügen“** existiert und dort eine **URL** (Streamable HTTP) eingegeben werden kann:

1. Symcon-Server starten (siehe oben).
2. In Claude die Symcon-URL eintragen: **http://127.0.0.1:4096** (oder SymBox-IP:4096).
3. Optional: Header `Authorization: Bearer DEIN_API_KEY` setzen, falls du einen MCP-API-Key nutzt.

Wenn es bei dir **nur** „.mcpb ziehen“ gibt, **Variante A** (Config-Datei) verwenden.

---

## 2. Claude-Anweisungen für „Überblick“ und interaktives Reden

Damit Claude sich beim **ersten Mal** einen Überblick verschafft und **mit dir redet**, kannst du folgende Anweisungen in Claude einfügen (z. B. unter **Custom Instructions**, **Projekt-Anweisungen** oder in der ersten Nachricht):

---

**Kopierblock für Claude (Custom Instructions / Projekt-Anweisungen):**

```
Du steuerst mein Smart Home über Symcon (MCP-Server "user-symcon" / symcon).

Erster Kontakt:
- Wenn ich das erste Mal in diesem Chat mit dem Smart Home spreche (z. B. "Hey, ich will mit meinem Haus reden" oder eine erste Steuerungsanfrage), sag zuerst: "Gib mir ein paar Sekunden, ich schaue mir dein Smart Home an." Rufe dann symcon_get_object_tree(rootId: 0, maxDepth: 4) und symcon_knowledge_get() auf. Fasse danach in 1–2 Sätzen zusammen, was du siehst (z. B. Räume, gelernte Geräte), und frage: "Was soll ich für dich schalten oder einstellen?"

Immer interaktiv:
- Rede mit mir: bestätige Aktionen ("Bürolicht ist an."), frage nach, wenn etwas unklar ist, und lerne neue Geräte, indem du mich frage ("Ist das dein Flurlicht?" → bei Ja: symcon_knowledge_set aufrufen).
- Für Lichter/Schalter: symcon_resolve_device("…") nutzen; wenn gefunden, symcon_request_action(variableId, true/false) oder symcon_set_value. Wenn nicht gelernt: Struktur erkunden, mich fragen, dann symcon_knowledge_set und Aktion ausführen.
```

---

## 3. Kurzablauf in Claude

| Du sagst | Claude soll |
|----------|-------------|
| Erstes Mal im Chat etwas zum Smart Home | "Gib mir ein paar Sekunden, ich schaue mir dein Smart Home an." → get_object_tree + knowledge_get → kurze Zusammenfassung → "Was soll ich schalten?" |
| "Schalte das Licht im Büro an" | resolve_device("Büro Licht") → wenn gefunden: request_action(36800, true) → "Bürolicht ist an." |
| Neues Gerät | Struktur erkunden, dich fragen ("Ist EG-FL-LI-1 dein Flurlicht?"), bei Ja: knowledge_set + Aktion |

---

## 4. Hinweise

- **MCP-Server muss laufen**, bevor Claude sich verbindet (localhost:4096 oder SymBox:4096).
- Bei **lokalem Server** (start-mcp-local.sh): Symcon-API (z. B. SymBox) muss vom Mac aus erreichbar sein; Passwort wird beim Start abgefragt.
- Die **Wissensbasis** (gelernte Geräte) liegt im MCP-Server (z. B. `data/symcon-knowledge.json`) und bleibt erhalten – auch in neuen Claude-Chats, solange derselbe MCP-Server läuft.
