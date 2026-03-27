import { loadProfile } from '../../config/loader.js';
import { runInstall } from '../../core/installer.js';
import { printSummary } from '../ui/summary.js';
import { c } from '../ui/theme.js';

export interface CheckCommandOptions {
  profile?: string;
  group?: string;
}

export async function checkCommand(opts: CheckCommandOptions): Promise<void> {
  console.log(c.brand.bold('\n  macinstall check') + c.dim(' — dry run\n'));

  let profile;
  try {
    profile = loadProfile(opts.profile);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(c.error('Error: ') + message);
    process.exit(1);
  }

  const summary = await runInstall(profile, {
    dryRun: true,
    group: opts.group,
    log: console.log,
  });

  printSummary(summary);
}
