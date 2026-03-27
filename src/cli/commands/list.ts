import Table from 'cli-table3';
import { loadProfile } from '../../config/loader.js';
import { isAppInstalled } from '../../core/detector.js';
import { c, icons } from '../ui/theme.js';

export interface ListCommandOptions {
  profile?: string;
  group?: string;
}

export async function listCommand(opts: ListCommandOptions): Promise<void> {
  console.log(c.brand.bold('\n  macinstall list\n'));

  let profile;
  try {
    profile = loadProfile(opts.profile);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(c.error('Error: ') + message);
    process.exit(1);
  }

  let apps = profile.apps;
  if (opts.group) {
    const groupIds = profile.groups?.[opts.group];
    if (!groupIds) {
      console.error(c.error(`Group "${opts.group}" not found`));
      process.exit(1);
    }
    const idSet = new Set(groupIds);
    apps = profile.apps.filter((a) => idSet.has(a.id));
  }

  const table = new Table({
    head: [c.bold('App'), c.bold('ID'), c.bold('Method'), c.bold('Status')],
    style: { head: [], border: ['dim'] },
    colWidths: [28, 28, 14, 12],
  });

  for (const app of apps) {
    const installed = await isAppInstalled(app);
    const statusStr = installed
      ? `${icons.installed} ${c.success('installed')}`
      : `${icons.pending} ${c.dim('not installed')}`;

    table.push([app.name, c.dim(app.id), c.dim(app.method), statusStr]);
  }

  console.log(table.toString());
  console.log(`\n  Total: ${apps.length} apps\n`);
}
