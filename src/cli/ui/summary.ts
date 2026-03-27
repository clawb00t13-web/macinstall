import Table from 'cli-table3';
import { InstallSummary } from '../../core/installer.js';
import { c, icons } from './theme.js';

export function printSummary(summary: InstallSummary): void {
  const { total, installed, skipped, failed, results, durationMs } = summary;

  console.log('\n' + c.bold('─── Install Summary ─────────────────────────────'));

  const table = new Table({
    head: [
      c.bold('App'),
      c.bold('Method'),
      c.bold('Status'),
      c.bold('Time'),
    ],
    style: { head: [], border: ['dim'] },
    colWidths: [30, 14, 12, 8],
  });

  for (const r of results) {
    let statusIcon: string;
    switch (r.status) {
      case 'installed': statusIcon = `${icons.installed} ${c.success('installed')}`; break;
      case 'skipped':   statusIcon = `${icons.skipped} ${c.dim('skipped')}`; break;
      case 'failed':    statusIcon = `${icons.failed} ${c.error('failed')}`; break;
      case 'pending':   statusIcon = `${icons.pending} ${c.dim('pending')}`; break;
      default:          statusIcon = r.status;
    }

    table.push([
      r.appName.length > 28 ? r.appName.slice(0, 25) + '...' : r.appName,
      c.dim(r.method),
      statusIcon,
      r.duration > 0 ? `${(r.duration / 1000).toFixed(1)}s` : '—',
    ]);
  }

  console.log(table.toString());

  console.log(
    `\n  ${icons.installed} ${c.success(String(installed))} installed  ` +
    `${icons.skipped} ${c.dim(String(skipped))} skipped  ` +
    `${icons.failed} ${failed > 0 ? c.error(String(failed)) : c.dim('0')} failed` +
    `  ${c.dim(`(${(durationMs / 1000).toFixed(1)}s total)`)}`
  );

  if (failed > 0) {
    console.log('\n' + c.error('Failed installs:'));
    for (const r of results.filter((r) => r.status === 'failed')) {
      console.log(`  ${icons.arrow} ${c.bold(r.appName)}: ${c.dim(r.error ?? 'unknown error')}`);
    }
  }

  console.log('');
}
