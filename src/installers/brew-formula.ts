import { execa } from 'execa';
import { AppEntry } from '../types/profile.js';
import { InstallResult } from '../types/installer.js';
import { BaseInstaller } from './base.js';

export class BrewFormulaInstaller extends BaseInstaller {
  readonly method = 'brew-formula';

  async isInstalled(app: AppEntry): Promise<boolean> {
    const formulaId = app.options?.version
      ? `${app.id}@${app.options.version}`
      : app.id;
    try {
      await execa('brew', ['list', formulaId], { stdio: 'pipe' });
      return true;
    } catch {
      return false;
    }
  }

  async install(app: AppEntry): Promise<InstallResult> {
    const start = Date.now();
    const formulaId = app.options?.version
      ? `${app.id}@${app.options.version}`
      : app.id;

    try {
      await execa('brew', ['install', formulaId], {
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
