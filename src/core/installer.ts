import { UserProfile, AppEntry } from '../types/profile.js';
import { InstallResult, InstallEvent } from '../types/installer.js';
import { bootstrap } from './bootstrap.js';
import { runQueue, EventHandler } from './queue.js';

export interface InstallOptions {
  skipIfInstalled?: boolean;
  dryRun?: boolean;
  group?: string;
  onEvent?: EventHandler;
  log?: (msg: string) => void;
}

export interface InstallSummary {
  total: number;
  installed: number;
  skipped: number;
  failed: number;
  results: InstallResult[];
  durationMs: number;
}

export async function runInstall(
  profile: UserProfile,
  opts: InstallOptions = {}
): Promise<InstallSummary> {
  const log = opts.log ?? console.log;
  const start = Date.now();

  // Bootstrap dependencies
  log('\nBootstrapping dependencies...');
  const bootstrapResult = await bootstrap(profile.bootstrap ?? {}, log);

  if (bootstrapResult.errors.length > 0) {
    log(`\nBootstrap warnings: ${bootstrapResult.errors.join(', ')}`);
  }

  // Resolve app list (optionally filtered by group)
  let apps: AppEntry[] = profile.apps;
  if (opts.group) {
    const groupIds = profile.groups?.[opts.group];
    if (!groupIds) {
      throw new Error(
        `Group "${opts.group}" not found. Available: ${Object.keys(profile.groups ?? {}).join(', ')}`
      );
    }
    const idSet = new Set(groupIds);
    apps = profile.apps.filter((a) => idSet.has(a.id));
  }

  log(`\nInstalling ${apps.length} app(s)${opts.dryRun ? ' [DRY RUN]' : ''}...\n`);

  const results = await runQueue(apps, {
    skipIfInstalled: opts.skipIfInstalled ?? profile.defaults?.skip_if_installed,
    defaultRetry: profile.defaults?.retry,
    onEvent: opts.onEvent,
    dryRun: opts.dryRun,
  });

  const summary: InstallSummary = {
    total: results.length,
    installed: results.filter((r) => r.status === 'installed').length,
    skipped: results.filter((r) => r.status === 'skipped').length,
    failed: results.filter((r) => r.status === 'failed').length,
    results,
    durationMs: Date.now() - start,
  };

  return summary;
}
