import { AppEntry } from '../types/profile.js';
import { InstallResult } from '../types/installer.js';

export abstract class BaseInstaller {
  abstract readonly method: string;

  abstract install(app: AppEntry): Promise<InstallResult>;
  abstract isInstalled(app: AppEntry): Promise<boolean>;

  protected makeResult(
    app: AppEntry,
    status: InstallResult['status'],
    opts: Partial<InstallResult> = {}
  ): InstallResult {
    return {
      appId: app.id,
      appName: app.name,
      status,
      method: this.method,
      duration: 0,
      attempts: 1,
      ...opts,
    };
  }
}
