import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import * as crypto from 'crypto';
import { execa } from 'execa';
import { AppEntry } from '../types/profile.js';
import { InstallResult } from '../types/installer.js';
import { BaseInstaller } from './base.js';

export class DmgInstaller extends BaseInstaller {
  readonly method = 'dmg';

  async isInstalled(app: AppEntry): Promise<boolean> {
    const appName = app.options?.app_name ?? `${app.name}.app`;
    return fs.existsSync(path.join('/Applications', appName));
  }

  async install(app: AppEntry): Promise<InstallResult> {
    const start = Date.now();
    const url = app.options?.url;
    const appName = app.options?.app_name ?? `${app.name}.app`;

    if (!url) {
      return this.makeResult(app, 'failed', {
        duration: Date.now() - start,
        error: 'DMG installer requires options.url',
      });
    }

    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'macinstall-'));
    const dmgPath = path.join(tmpDir, `${app.id}.dmg`);
    let mountPath: string | null = null;

    try {
      // Download DMG
      console.log(`  Downloading ${app.name}...`);
      await execa('curl', ['-L', '-o', dmgPath, url], { stdio: 'inherit' });

      // Verify SHA256 if provided
      if (app.options?.sha256) {
        const hash = crypto
          .createHash('sha256')
          .update(fs.readFileSync(dmgPath))
          .digest('hex');
        if (hash.toLowerCase() !== app.options.sha256.toLowerCase()) {
          throw new Error(
            `SHA256 mismatch for ${app.name}: expected ${app.options.sha256}, got ${hash}`
          );
        }
      }

      // Mount DMG
      console.log(`  Mounting ${app.name}...`);
      const { stdout: mountOutput } = await execa(
        'hdiutil',
        ['attach', '-nobrowse', '-plist', dmgPath],
        { stdio: 'pipe' }
      );
      mountPath = parseMountPoint(mountOutput);

      if (!mountPath) {
        throw new Error(`Failed to determine mount point for ${app.name}`);
      }

      // Find .app in mounted volume
      const entries = fs.readdirSync(mountPath);
      const appBundle = entries.find((e) => e === appName || e.endsWith('.app'));
      if (!appBundle) {
        throw new Error(`No .app bundle found in ${mountPath}`);
      }

      // Copy to /Applications
      console.log(`  Installing ${app.name} to /Applications...`);
      await execa(
        'cp',
        ['-R', path.join(mountPath, appBundle), '/Applications/'],
        { stdio: 'inherit' }
      );

      return this.makeResult(app, 'installed', { duration: Date.now() - start });
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return this.makeResult(app, 'failed', {
        duration: Date.now() - start,
        error: message,
      });
    } finally {
      // Unmount and cleanup
      if (mountPath) {
        try {
          await execa('hdiutil', ['detach', mountPath], { stdio: 'pipe' });
        } catch {
          // Best-effort cleanup
        }
      }
      try {
        fs.rmSync(tmpDir, { recursive: true });
      } catch {
        // Best-effort cleanup
      }
    }
  }
}

function parseMountPoint(plistOutput: string): string | null {
  // hdiutil outputs a plist; find the mount point via simple regex
  const match = plistOutput.match(/<string>(\/Volumes\/[^<]+)<\/string>/);
  return match ? match[1] : null;
}
