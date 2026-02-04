# Symcon-Smart-Home in Claude einbinden

So nutzt du dein Symcon-Smart-Home **mit Claude** (Anthropic): MCP-Server verbinden + Anweisungen für „erster Überblick“ und interaktives Reden.

---

## 1. MCP-Server in Claude verbinden

1. **Symcon MCP-Server starten** (lokal auf dem Mac):
   ```bash
   cd symcon-mcp-server
   ./start-mcp-local.sh
   ```
   Passwort eingeben, wenn gefragt. Server läuft auf **http://127.0.0.1:4096**.

2. **In Claude:** Einstellungen öffnen → **MCP** (oder „Tools“ / „Integrations“) → **Server hinzufügen**.

3. **Streamable HTTP** wählen, URL eintragen:
   - **http://127.0.0.1:4096** (wenn der Server lokal auf dem Mac läuft)
   - oder **http://&lt;SymBox-IP&gt;:4096**, wenn der Server auf der SymBox läuft.

4. **Optional:** Wenn du einen MCP-API-Key gesetzt hast, unter Headers eintragen:
   - Name: `Authorization`, Wert: `Bearer DEIN_API_KEY`
   - oder Name: `X-MCP-API-Key`, Wert: `DEIN_API_KEY`

5. Speichern – Claude lädt die Symcon-Tools (symcon_resolve_device, symcon_set_value, symcon_knowledge_get, symcon_get_object_tree, …).

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
