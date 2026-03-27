import { AppEntry } from '../types/profile.js';
import { getInstallerForApp } from '../installers/index.js';
import { resolveAutoMethod } from '../catalog/index.js';

export async function isAppInstalled(app: AppEntry): Promise<boolean> {
  // For auto method, resolve first
  const effectiveApp = resolveApp(app);
  if (!effectiveApp) return false;

  try {
    const installer = getInstallerForApp(effectiveApp);
    return await installer.isInstalled(effectiveApp);
  } catch {
    return false;
  }
}

export function resolveApp(app: AppEntry): AppEntry | null {
  if (app.method !== 'auto') return app;

  const resolved = resolveAutoMethod(app.id);
  if (!resolved) return null;

  return {
    ...app,
    method: resolved.method as AppEntry['method'],
    id: resolved.resolvedId ?? app.id,
  };
}
