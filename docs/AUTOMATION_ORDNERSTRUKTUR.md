# MCP-Automationen: Ordnerstruktur und Logik

Wenn der MCP Skripte und zeitgesteuerte Events anlegt (z. B. „Rolllade in 10 Minuten hoch“, „Ambiente morgens orange, tagsüber blau“), sollen diese **nicht wild in einem einzigen Ordner** landen, sondern in einer **sinnvollen, anlass- oder raumbezogenen Struktur**.

## Grundprinzip

- **Eine** zentrale Wurzel im Symcon-Objektbaum, z. B. **„MCP Automations“** (oder „KI-Assistent“), damit alle von der KI angelegten Skripte/Events gebündelt und erkennbar sind.
- **Darunter:** thematische und/oder räumliche Unterordner, damit die KI gezielt suchen, aktualisieren und aufräumen kann.

## Empfohlene Struktur (zweistufig)

```
MCP Automations
├── Timer / Einmalig     … einmalige Zeitsteuerungen („in 10 Min Rolllade hoch“)
├── Licht / Ambiente     … Lichtszenen, Tageszeiten (morgens orange, tagsüber blau)
├── Rollladen            … zeit- oder ereignisgesteuerte Jalousien/Rollos
├── Räume                … raumspezifische Misch-Automationen (optional)
│   ├── Büro
│   ├── Küche
│   └── …
└── Sonstige             … was keinem klaren Thema/Raum zugeordnet wird
```

### Logik für die KI

1. **Thema erkennbar** (Licht, Rolllade, Timer, …)  
   → Skript/Event unter dem passenden **thematischen Ordner** anlegen (z. B. „Licht / Ambiente“, „Rollladen“, „Timer / Einmalig“).

2. **Raum explizit genannt** („Büro-Rolllade in 10 Min“, „Ambiente im Wohnzimmer“)  
   - **Option A:** Weiterhin unter Thema ablegen, Namen/Skript enthalten den Raum (z. B. unter „Timer / Einmalig“ → „Büro Rolllade 10min“).  
   - **Option B:** Zusätzlich unter **Räume → [Raum]** ablegen oder nur dort, wenn die Automation **ausschließlich** für diesen Raum ist und thematisch gemischt (z. B. „Büro“ → „Licht + Rollladen“).

3. **Weder Thema noch Raum klar**  
   → Unter **„Sonstige“** ablegen.

4. **Aufräumen / Ändern**  
   - Bei Änderungswunsch („mach das Ambiente anders“, „Rolllade-Timer weg“): Zuerst in dem **thematischen** (und ggf. **Räume → Raum**) Ordner suchen, vorhandene Skripte/Events auflisten, dann **aktualisieren oder löschen** statt neu anlegen.

### Konkret: Wo landet was?

| User-Wunsch | Ordner |
|-------------|--------|
| „Rolllade in 10 Minuten hoch“ | **Timer / Einmalig** (Name z. B. „Rolllade [Raum] 10min“) |
| „Ambiente morgens/abends orange, tagsüber blau“ | **Licht / Ambiente** |
| „Jeden Morgen um 7 Büro-Rolllade hoch“ | **Rollladen** oder **Räume → Büro** (Konvention festlegen) |
| „Licht im Flur ab 18 Uhr an“ | **Licht / Ambiente** oder **Räume → Flur** |

Eine feste Konvention (z. B. „zeitgesteuerte Geräte immer unter Thema, nur bei explizitem ‚alles für Raum X‘ unter Räume“) hält die Struktur konsistent und für die KI gut abfragbar.

## Technik (bei Implementierung)

- Symcon-Kategorien sind Objekte (ObjectType 0). Unter „MCP Automations“ werden **Unterkategorien** angelegt (per API: Kategorie-Objekt erstellen, `IPS_SetParent` auf die jeweilige Parent-ID, `IPS_SetName` für die Anzeige).
- Beim **ersten Anlegen** einer Automation prüfen, ob die Wurzel „MCP Automations“ und die benötigten Unterordner (Timer, Licht, Rollladen, Räume, Sonstige) existieren; falls nicht, anlegen.
- **Räume-Unterordner** nur anlegen, wenn der User einen konkreten Raum nennt und die gewählte Logik „Räume“ vorsieht; Raumnamen aus Wissensbasis oder Objektbaum übernehmen (z. B. „Büro“, „Wohnzimmer“), damit es zur bestehenden Symcon-Struktur passt.

## Kurzfassung

- **Eine** Wurzel: „MCP Automations“.
- **Darunter** thematische Ordner (Timer, Licht/Ambiente, Rollladen, Sonstige) und optional **Räume** mit Unterordnern pro Raum.
- KI ordnet jede Automation **einem** (Haupt-)Ordner zu und legt dort an bzw. räumt dort auf; keine Duplikate, klare Zuordnung für spätere Änderungen.
