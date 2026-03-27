import { execSync, spawnSync } from 'child_process';
import { BootstrapConfig } from '../types/profile.js';

export interface BootstrapResult {
  homebrewInstalled: boolean;
  masInstalled: boolean;
  errors: string[];
}

function commandExists(cmd: string): boolean {
  try {
    execSync(`which ${cmd}`, { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

export async function bootstrap(
  config: BootstrapConfig = {},
  log: (msg: string) => void = console.log
): Promise<BootstrapResult> {
  const result: BootstrapResult = {
    homebrewInstalled: false,
    masInstalled: false,
    errors: [],
  };

  const installHomebrew = config.homebrew !== false; // default: true
  const installMas = config.mas !== false; // default: true

  // Check / install Homebrew
  if (commandExists('brew')) {
    log('  Homebrew already installed');
    result.homebrewInstalled = true;
  } else if (installHomebrew) {
    log('  Installing Homebrew...');
    const installScript =
      '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';
    const ret = spawnSync('bash', ['-c', installScript], { stdio: 'inherit' });
    if (ret.status === 0) {
      // Add brew to PATH for the current process
      try {
        const brewPath = execSync('which brew 2>/dev/null || echo /opt/homebrew/bin/brew', {
          encoding: 'utf8',
        }).trim();
        const brewDir = brewPath.replace('/brew', '');
        process.env['PATH'] = `${brewDir}:${process.env['PATH']}`;
      } catch {
        // ignore
      }
      result.homebrewInstalled = true;
      log('  Homebrew installed successfully');
    } else {
      const msg = 'Homebrew installation failed';
      result.errors.push(msg);
      log(`  ERROR: ${msg}`);
    }
  }

  // Check / install mas
  if (!result.homebrewInstalled && installMas) {
    result.errors.push('Cannot install mas: Homebrew is not available');
    return result;
  }

  if (commandExists('mas')) {
    log('  mas-cli already installed');
    result.masInstalled = true;
  } else if (installMas && result.homebrewInstalled) {
    log('  Installing mas-cli...');
    const ret = spawnSync('brew', ['install', 'mas'], { stdio: 'inherit' });
    if (ret.status === 0) {
      result.masInstalled = true;
      log('  mas-cli installed successfully');
    } else {
      const msg = 'mas-cli installation failed';
      result.errors.push(msg);
      log(`  ERROR: ${msg}`);
    }
  }

  return result;
}
