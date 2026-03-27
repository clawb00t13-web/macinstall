import * as fs from 'fs';
import * as path from 'path';
import * as url from 'url';
import { Catalog } from '../types/catalog.js';

const __dirname = path.dirname(url.fileURLToPath(import.meta.url));

// Bundled catalog ships with the npm package
const BUNDLED_CATALOG_PATH = path.join(__dirname, '../../catalog/apps.json');

let _catalog: Catalog | null = null;

export function loadCatalog(): Catalog {
  if (_catalog) return _catalog;

  // Try bundled catalog first
  if (fs.existsSync(BUNDLED_CATALOG_PATH)) {
    const raw = fs.readFileSync(BUNDLED_CATALOG_PATH, 'utf8');
    const parsed = JSON.parse(raw);
    // Normalize legacy format if needed
    _catalog = normalizeCatalog(parsed);
    return _catalog;
  }

  // Empty fallback
  _catalog = {
    version: 0,
    generatedAt: new Date().toISOString(),
    apps: [],
    categories: [],
  };
  return _catalog;
}

function normalizeCatalog(raw: Record<string, unknown>): Catalog {
  // Handle legacy format from existing catalog/apps.json
  if (Array.isArray(raw['apps'])) {
    const apps = (raw['apps'] as Record<string, unknown>[]).map((a) => ({
      id: String(a['id'] ?? ''),
      name: String(a['name'] ?? ''),
      description: a['description'] ? String(a['description']) : undefined,
      category: Array.isArray(a['categories']) ? String(a['categories'][0]) : 'other',
      verified: false,
      methods: {
        preferred: a['brew_cask']
          ? 'brew-cask'
          : a['brew_formula']
          ? 'brew-formula'
          : a['mas_id']
          ? 'mas'
          : 'brew-cask',
        brewCask: a['brew_cask'] ? String(a['brew_cask']) : undefined,
        brewFormula: a['brew_formula'] ? String(a['brew_formula']) : undefined,
        mas: a['mas_id'] ? Number(a['mas_id']) : undefined,
      },
    }));

    return {
      version: Number(raw['version'] ?? 1),
      generatedAt: String(raw['updated'] ?? new Date().toISOString()),
      apps,
      categories: [],
    };
  }

  return raw as unknown as Catalog;
}
