import * as os from 'os';
import * as path from 'path';

export const DEFAULT_PROFILE_PATHS = [
  path.join(os.homedir(), '.macinstall.yml'),
  path.join(os.homedir(), '.macinstall.yaml'),
  path.join(os.homedir(), '.macinstall.json'),
  path.join(process.cwd(), 'macinstall.yml'),
  path.join(process.cwd(), 'macinstall.yaml'),
];

export const DEFAULT_RETRY = 2;
export const DEFAULT_TIMEOUT = 300; // seconds
export const DEFAULT_SKIP_IF_INSTALLED = true;

export const CATALOG_CACHE_PATH = path.join(
  os.homedir(),
  '.cache',
  'macinstall',
  'catalog.json'
);

export const CATALOG_CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours
