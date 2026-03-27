import { execa } from 'execa';
import { AppEntry } from '../types/profile.js';
import { InstallResult } from '../types/installer.js';
import { BaseInstaller } from './base.js';

export class BrewCaskInstaller extends BaseInstaller {
  readonly method = 'brew-cask';

  async isInstalled(app: AppEntry): Promise<boolean> {
    try {
      await execa('brew', ['list', '--cask', app.id], { stdio: 'pipe' });
      return true;
    } catch {
      return false;
    }
  }

  async install(app: AppEntry): Promise<InstallResult> {
    const start = Date.now();
    try {
      await execa('brew', ['install', '--cask', app.id], {
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
