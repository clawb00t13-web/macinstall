import { loadProfile } from '../../config/loader.js';
import { runInstall } from '../../core/installer.js';
import { ProgressReporter } from '../ui/progress.js';
import { printSummary } from '../ui/summary.js';
import { c } from '../ui/theme.js';

export interface InstallCommandOptions {
  profile?: string;
  dryRun?: boolean;
  group?: string;
  skipInstalled?: boolean;
}

export async function installCommand(opts: InstallCommandOptions): Promise<void> {
  console.log(c.brand.bold('\n  macinstall') + c.dim(' — Mac App Auto-Installer\n'));

  // Load profile
  let profile;
  try {
    profile = loadProfile(opts.profile);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(c.error('Error: ') + message);
    process.exit(1);
  }

  if (profile.meta?.name) {
    console.log(`  Profile: ${c.bold(profile.meta.name)}`);
  }
  console.log(`  Apps:    ${c.bold(String(profile.apps.length))}`);
  if (opts.group) {
    console.log(`  Group:   ${c.bold(opts.group)}`);
  }
  if (opts.dryRun) {
    console.log(`  Mode:    ${c.warning('DRY RUN (no changes will be made)')}`);
  }

  const reporter = new ProgressReporter();

  try {
    const summary = await runInstall(profile, {
      dryRun: opts.dryRun,
      group: opts.group,
      skipIfInstalled: opts.skipInstalled,
      onEvent: (event) => reporter.handleEvent(event),
      log: (msg) => {
        reporter.stop();
        console.log(msg);
      },
    });

    reporter.stop();
    printSummary(summary);

    if (summary.failed > 0) {
      process.exit(1);
    }
  } catch (err: unknown) {
    reporter.stop();
    const message = err instanceof Error ? err.message : String(err);
    console.error('\n' + c.error('Fatal error: ') + message);
    process.exit(1);
  }
}
