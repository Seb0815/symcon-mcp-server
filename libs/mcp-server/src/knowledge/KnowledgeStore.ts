/**
 * Persistente Wissensbasis: Geräte-Zuordnungen (z. B. „Büro Licht“ → Variable Zustand von EG-BU-LI-1).
 * Wird vom MCP-Server gelesen/geschrieben, damit die KI gelernte Zuordnungen nutzen kann.
 */

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface DeviceMapping {
  /** Eindeutige ID (z. B. "buero-licht") */
  id: string;
  /** Nutzer-Label für Sprache: "Büro Licht", "Bürolicht", "Licht im Büro" */
  userLabel: string;
  /** Symcon VariableID (für SetValue/RequestAction) */
  variableId: number;
  /** Name der Variable in Symcon (z. B. "Zustand") */
  variableName: string;
  /** Optional: Pfad im Objektbaum (z. B. "Räume/Erdgeschoss/Büro/EG-BU-LI-1/Zustand") */
  path?: string;
  /** Optional: ObjectID des übergeordneten Geräts (z. B. EG-BU-LI-1) */
  objectId?: number;
}

export interface Convention {
  key: string;
  meaning: string;
  description?: string;
}

export interface ControlRule {
  variableId: number;
  variableName?: string;
  deviceType?: string;
  actions: Record<string, number | boolean>;
  source?: string;
  note?: string;
  updatedAt?: string;
}

export interface KnowledgeData {
  deviceMappings: DeviceMapping[];
  conventions?: Convention[];
  controlRules?: ControlRule[];
}

const DEFAULT_FILENAME = 'symcon-knowledge.json';

function getDataDir(): string {
  const envPath = process.env.SYMCON_KNOWLEDGE_PATH;
  if (envPath) return dirname(envPath);
  return join(process.cwd(), 'data');
}

function getFilePath(): string {
  const envPath = process.env.SYMCON_KNOWLEDGE_PATH;
  if (envPath) return envPath;
  return join(process.cwd(), 'data', DEFAULT_FILENAME);
}

export class KnowledgeStore {
  private filePath: string = getFilePath();
  private data: KnowledgeData = { deviceMappings: [], conventions: [], controlRules: [] };
  private loaded = false;

  private async ensureLoaded(): Promise<void> {
    if (this.loaded) return;
    try {
      const raw = await readFile(this.filePath, 'utf8');
      this.data = JSON.parse(raw) as KnowledgeData;
      if (!Array.isArray(this.data.deviceMappings)) this.data.deviceMappings = [];
      if (!Array.isArray(this.data.conventions)) this.data.conventions = [];
      if (!Array.isArray(this.data.controlRules)) this.data.controlRules = [];
    } catch {
      this.data = { deviceMappings: [], conventions: [], controlRules: [] };
    }
    this.loaded = true;
  }

  private async save(): Promise<void> {
    const dir = dirname(this.filePath);
    await mkdir(dir, { recursive: true });
    await writeFile(this.filePath, JSON.stringify(this.data, null, 2), 'utf8');
  }

  async getMappings(): Promise<DeviceMapping[]> {
    await this.ensureLoaded();
    return [...this.data.deviceMappings];
  }

  async getConventions(): Promise<Convention[]> {
    await this.ensureLoaded();
    return [...(this.data.conventions ?? [])];
  }

  async getControlRules(): Promise<ControlRule[]> {
    await this.ensureLoaded();
    return [...(this.data.controlRules ?? [])];
  }

  async addOrUpdateMapping(mapping: Omit<DeviceMapping, 'id'> & { id?: string }): Promise<DeviceMapping> {
    await this.ensureLoaded();
    const id = mapping.id ?? this.slug(mapping.userLabel);
    const existing = this.data.deviceMappings.find((m) => m.id === id);
    const entry: DeviceMapping = {
      id,
      userLabel: mapping.userLabel.trim(),
      variableId: mapping.variableId,
      variableName: mapping.variableName.trim(),
      path: mapping.path?.trim(),
      objectId: mapping.objectId,
    };
    if (existing) {
      const idx = this.data.deviceMappings.indexOf(existing);
      this.data.deviceMappings[idx] = entry;
    } else {
      this.data.deviceMappings.push(entry);
    }
    await this.save();
    return entry;
  }

  async addOrUpdateConvention(convention: Convention): Promise<Convention> {
    await this.ensureLoaded();
    const key = convention.key.trim();
    const existing = (this.data.conventions ?? []).find((c) => c.key.toLowerCase() === key.toLowerCase());
    const entry: Convention = {
      key,
      meaning: convention.meaning.trim(),
      description: convention.description?.trim(),
    };
    if (!this.data.conventions) this.data.conventions = [];
    if (existing) {
      const idx = this.data.conventions.indexOf(existing);
      this.data.conventions[idx] = entry;
    } else {
      this.data.conventions.push(entry);
    }
    await this.save();
    return entry;
  }

  async addOrUpdateControlRule(rule: ControlRule): Promise<ControlRule> {
    await this.ensureLoaded();
    if (!this.data.controlRules) this.data.controlRules = [];
    const existing = this.data.controlRules.find((r) => r.variableId === rule.variableId);
    const entry: ControlRule = {
      variableId: rule.variableId,
      variableName: rule.variableName?.trim(),
      deviceType: rule.deviceType?.trim(),
      actions: { ...rule.actions },
      source: rule.source?.trim(),
      note: rule.note?.trim(),
      updatedAt: new Date().toISOString(),
    };
    if (existing) {
      const idx = this.data.controlRules.indexOf(existing);
      this.data.controlRules[idx] = entry;
    } else {
      this.data.controlRules.push(entry);
    }
    await this.save();
    return entry;
  }

  async getControlRuleByVariableId(variableId: number): Promise<ControlRule | null> {
    await this.ensureLoaded();
    const rule = (this.data.controlRules ?? []).find((r) => r.variableId === variableId);
    return rule ? { ...rule, actions: { ...rule.actions } } : null;
  }

  async correctDirection(variableId: number, note?: string): Promise<ControlRule | null> {
    await this.ensureLoaded();
    if (!this.data.controlRules) this.data.controlRules = [];
    const existing = this.data.controlRules.find((r) => r.variableId === variableId);
    if (!existing) return null;

    const pairs: Array<[string, string]> = [
      ['auf', 'zu'],
      ['aufmachen', 'zumachen'],
      ['open', 'close'],
      ['hoch', 'runter'],
      ['hochfahren', 'runterfahren'],
      ['hochziehen', 'runterziehen'],
      ['rauf', 'runter'],
      ['up', 'down'],
    ];

    let changed = false;
    for (const [a, b] of pairs) {
      if (a in existing.actions && b in existing.actions) {
        const tmp = existing.actions[a];
        existing.actions[a] = existing.actions[b];
        existing.actions[b] = tmp;
        changed = true;
      }
    }

    if (!changed) return null;

    if (note) {
      existing.note = note.trim();
    }
    existing.updatedAt = new Date().toISOString();
    await this.save();
    return { ...existing, actions: { ...existing.actions } };
  }

  /** Sucht anhand eines Nutzer-Phrase (z. B. "Büro Licht", "Licht im Büro") eine passende Zuordnung. */
  async resolve(userPhrase: string): Promise<DeviceMapping | null> {
    await this.ensureLoaded();
    const norm = this.normalize(userPhrase);
    if (!norm) return null;
    for (const m of this.data.deviceMappings) {
      if (this.normalize(m.userLabel).includes(norm) || norm.includes(this.normalize(m.userLabel))) return m;
    }
    return null;
  }

  private slug(label: string): string {
    return label
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9-]/g, '');
  }

  private normalize(s: string): string {
    return s
      .trim()
      .toLowerCase()
      .replace(/\s+/g, ' ');
  }
}

let defaultStore: KnowledgeStore | null = null;

export function getKnowledgeStore(): KnowledgeStore {
  if (!defaultStore) defaultStore = new KnowledgeStore();
  return defaultStore;
}
