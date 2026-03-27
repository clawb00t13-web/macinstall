import ora, { Ora } from 'ora';
import { InstallEvent } from '../../types/installer.js';
import { c, icons } from './theme.js';

export class ProgressReporter {
  private spinner: Ora | null = null;
  private currentApp: string | null = null;

  handleEvent(event: InstallEvent): void {
    switch (event.type) {
      case 'start':
        this.currentApp = event.appName;
        this.spinner = ora({
          text: `Installing ${c.bold(event.appName)}...`,
          color: 'cyan',
        }).start();
        break;

      case 'retry':
        if (this.spinner) {
          this.spinner.text = `${c.bold(event.appName)} ${c.warning(event.message ?? 'retrying...')}`;
        }
        break;

      case 'complete':
        this.spinner?.succeed(
          `${icons.installed} ${c.bold(event.appName)} ${c.dim(`(${event.result?.method ?? ''})`)} ${c.success('installed')}`
        );
        this.spinner = null;
        break;

      case 'skip':
        this.spinner?.stopAndPersist({
          symbol: icons.skipped,
          text: `${c.dim(event.appName)} ${c.dim('already installed, skipped')}`,
        });
        this.spinner = null;
        break;

      case 'error':
        this.spinner?.fail(
          `${icons.failed} ${c.bold(event.appName)} ${c.error('failed')}` +
          (event.result?.error ? `: ${c.dim(event.result.error)}` : '')
        );
        this.spinner = null;
        break;
    }
  }

  stop(): void {
    this.spinner?.stop();
  }
}
