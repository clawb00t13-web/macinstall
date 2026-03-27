import { execa } from 'execa';
import { AppEntry } from '../types/profile.js';
import { InstallResult } from '../types/installer.js';
import { BaseInstaller } from './base.js';

export class MasInstaller extends BaseInstaller {
  readonly method = 'mas';

  private getMasId(app: AppEntry): string {
    if (app.options?.mas_id) return String(app.options.mas_id);
    // Try to parse numeric id from app.id
    if (/^\d+$/.test(app.id)) return app.id;
    throw new Error(
      `App "${app.name}" uses method: mas but has no numeric id or options.mas_id`
    );
  }

  async isInstalled(app: AppEntry): Promise<boolean> {
    try {
      const masId = this.getMasId(app);
      const { stdout } = await execa('mas', ['list'], { stdio: 'pipe' });
      return stdout.includes(masId);
    } catch {
      return false;
    }
  }

  async install(app: AppEntry): Promise<InstallResult> {
    const start = Date.now();
    try {
      const masId = this.getMasId(app);
      await execa('mas', ['install', masId], {
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
