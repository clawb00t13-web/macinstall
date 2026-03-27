export interface CatalogAppMethods {
  preferred: string;
  brewCask?: string;
  brewFormula?: string;
  mas?: number;
  dmg?: {
    url: string;
    appName: string;
  };
}

export interface CatalogAppDetection {
  bundleId?: string;
  appName?: string;
  brewCaskCheck?: string;
}

export interface CatalogAppMeta {
  tags?: string[];
  license?: string;
  freeOrPaid?: 'free' | 'paid' | 'freemium';
  minMacOS?: string;
}

export interface CatalogApp {
  id: string;
  name: string;
  description?: string;
  homepage?: string;
  category: string;
  iconUrl?: string;
  verified: boolean;
  methods: CatalogAppMethods;
  detection?: CatalogAppDetection;
  meta?: CatalogAppMeta;
}

export interface CatalogCategory {
  id: string;
  name: string;
  icon?: string;
}

export interface Catalog {
  version: number;
  generatedAt: string;
  apps: CatalogApp[];
  categories: CatalogCategory[];
}
