import { AppEntry } from '../types/profile.js';
import { BaseInstaller } from './base.js';
import { BrewCaskInstaller } from './brew-cask.js';
import { BrewFormulaInstaller } from './brew-formula.js';
import { MasInstaller } from './mas.js';
import { DmgInstaller } from './dmg.js';
import { ScriptInstaller } from './script.js';

const registry: Record<string, BaseInstaller> = {
  'brew-cask': new BrewCaskInstaller(),
  'brew-formula': new BrewFormulaInstaller(),
  mas: new MasInstaller(),
  dmg: new DmgInstaller(),
  script: new ScriptInstaller(),
};

export function getInstaller(method: string): BaseInstaller {
  const installer = registry[method];
  if (!installer) {
    throw new Error(
      `Unknown install method: "${method}". Valid methods: ${Object.keys(registry).join(', ')}`
    );
  }
  return installer;
}

export function getInstallerForApp(app: AppEntry): BaseInstaller {
  return getInstaller(app.method);
}
