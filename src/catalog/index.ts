import { CatalogApp } from '../types/catalog.js';
import { loadCatalog } from './loader.js';

export function findById(id: string): CatalogApp | undefined {
  const catalog = loadCatalog();
  return catalog.apps.find((a) => a.id === id);
}

export function findByName(name: string): CatalogApp | undefined {
  const catalog = loadCatalog();
  const lower = name.toLowerCase();
  return catalog.apps.find((a) => a.name.toLowerCase() === lower);
}

export function search(query: string): CatalogApp[] {
  const catalog = loadCatalog();
  const lower = query.toLowerCase();
  return catalog.apps.filter(
    (a) =>
      a.id.includes(lower) ||
      a.name.toLowerCase().includes(lower) ||
      a.description?.toLowerCase().includes(lower)
  );
}

export function resolveAutoMethod(
  appId: string
): { method: string; resolvedId?: string } | null {
  const app = findById(appId);
  if (!app) return null;

  const preferred = app.methods.preferred;

  // Return the resolved ID for the preferred method
  switch (preferred) {
    case 'brew-cask':
      return { method: 'brew-cask', resolvedId: app.methods.brewCask };
    case 'brew-formula':
      return { method: 'brew-formula', resolvedId: app.methods.brewFormula };
    case 'mas':
      return {
        method: 'mas',
        resolvedId: app.methods.mas ? String(app.methods.mas) : undefined,
      };
    default:
      return { method: preferred };
  }
}
