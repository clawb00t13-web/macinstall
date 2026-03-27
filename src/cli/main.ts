#!/usr/bin/env node
import { Command } from 'commander';
import { installCommand } from './commands/install.js';
import { checkCommand } from './commands/check.js';
import { listCommand } from './commands/list.js';
import { initCommand } from './commands/init.js';

const program = new Command();

program
  .name('macinstall')
  .description('Mac App Auto-Installer — build your app list once, run anywhere')
  .version('0.1.0');

program
  .command('install')
  .alias('apply')
  .description('Install all apps from your profile')
  .option('-p, --profile <path>', 'Path to profile YAML/JSON file')
  .option('-g, --group <name>', 'Install only apps in a named group')
  .option('--dry-run', 'Preview what would be installed without making changes')
  .option('--no-skip-installed', 'Re-install apps that are already installed')
  .action((opts) =>
    installCommand({
      profile: opts.profile,
      dryRun: opts.dryRun,
      group: opts.group,
      skipInstalled: opts.skipInstalled,
    })
  );

program
  .command('check')
  .description('Dry-run: preview what would be installed (no changes made)')
  .option('-p, --profile <path>', 'Path to profile YAML/JSON file')
  .option('-g, --group <name>', 'Filter to a named group')
  .action((opts) => checkCommand({ profile: opts.profile, group: opts.group }));

program
  .command('list')
  .description('List all apps in your profile with install status')
  .option('-p, --profile <path>', 'Path to profile YAML/JSON file')
  .option('-g, --group <name>', 'Filter to a named group')
  .action((opts) => listCommand({ profile: opts.profile, group: opts.group }));

program
  .command('init')
  .description('Create a starter profile at ~/.macinstall.yml')
  .action(() => initCommand());

// Default: if no subcommand given, run install
program
  .argument('[profile]', 'Profile file path (shorthand for: macinstall install --profile <path>)')
  .action((profileArg, opts) => {
    if (profileArg) {
      return installCommand({ profile: profileArg });
    }
    // No args at all — show help
    program.help();
  });

program.parseAsync(process.argv).catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error('Error:', message);
  process.exit(1);
});
