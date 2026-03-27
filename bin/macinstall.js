#!/usr/bin/env node
// ESM bin shim — delegates to compiled TypeScript output
import { createRequire } from 'module';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { existsSync } from 'fs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const distEntry = join(__dirname, '../dist/cli/main.js');

if (existsSync(distEntry)) {
  await import(distEntry);
} else {
  console.error('Error: CLI not built. Run: npm run build');
  process.exit(1);
}
