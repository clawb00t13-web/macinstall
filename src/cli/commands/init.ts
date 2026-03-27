import * as fs from 'fs';
import * as path from 'path';
import * as os from 'os';
import { c } from '../ui/theme.js';

const TEMPLATE = `# macinstall profile
# https://github.com/macinstall/macinstall

version: 1

meta:
  name: My Mac Setup
  description: Personal app setup

defaults:
  retry: 2
  timeout: 300
  skip_if_installed: true

bootstrap:
  homebrew: true
  mas: true

apps:
  # Homebrew Casks (GUI apps)
  - id: visual-studio-code
    name: Visual Studio Code
    method: brew-cask

  - id: arc
    name: Arc
    method: brew-cask

  # Homebrew Formulas (CLI tools)
  - id: git
    name: Git
    method: brew-formula

  - id: ripgrep
    name: ripgrep
    method: brew-formula

  # Mac App Store (requires being signed in)
  # - id: "497799835"
  #   name: Xcode
  #   method: mas
  #   options:
  #     mas_id: 497799835

groups:
  essentials:
    - visual-studio-code
    - arc
    - git
`;

export async function initCommand(): Promise<void> {
  const defaultPath = path.join(os.homedir(), '.macinstall.yml');

  if (fs.existsSync(defaultPath)) {
    console.log(c.warning(`Profile already exists at ${defaultPath}`));
    console.log(c.dim('Edit it directly or pass --profile to use a different path.'));
    return;
  }

  fs.writeFileSync(defaultPath, TEMPLATE, 'utf8');
  console.log(c.success(`\n  Created profile at ${c.bold(defaultPath)}`));
  console.log(c.dim('\n  Edit the file to add your apps, then run:'));
  console.log(`  ${c.brand.bold('macinstall install')}\n`);
}
