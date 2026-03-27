import { execa } from 'execa';
import { AppEntry } from '../types/profile.js';
import { InstallResult } from '../types/installer.js';
import { BaseInstaller } from './base.js';

export class ScriptInstaller extends BaseInstaller {
  readonly method = 'script';

  async isInstalled(app: AppEntry): Promise<boolean> {
    const checkCmd = app.options?.check_command;
    if (!checkCmd) return false;
    try {
      await execa('sh', ['-c', checkCmd], { stdio: 'pipe' });
      return true;
    } catch {
      return false;
    }
  }

  async install(app: AppEntry): Promise<InstallResult> {
    const start = Date.now();
    const script = app.options?.script;

    if (!script) {
      return this.makeResult(app, 'failed', {
        duration: Date.now() - start,
        error: 'Script installer requires options.script',
      });
    }

    try {
      await execa('sh', ['-c', script], {
        stdio: 'inherit',
        timeout: (app.timeout ?? 300) * 1000,
      });
      return this.makeResult(app, 'installed', { duration: Date.now() - start });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return this.makeResult(app, 'failed', {
        duration: Date.now() - start,
        error: message,
      });
    }
  }
}
