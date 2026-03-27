export type InstallMethod =
  | 'brew-cask'
  | 'brew-formula'
  | 'mas'
  | 'dmg'
  | 'script'
  | 'auto';

export interface AppOptions {
  // brew-formula: install specific version (e.g. node@22)
  version?: string;
  // mas: explicit numeric App Store ID
  mas_id?: number;
  // dmg: download URL and optional integrity check
  url?: string;
  sha256?: string;
  app_name?: string;
  // script: the shell command to run, and optional check
  script?: string;
  check_command?: string;
}

export interface AppEntry {
  id: string;
  name: string;
  method: InstallMethod;
  options?: AppOptions;
  retry?: number;
  timeout?: number;
  optional?: boolean;
  note?: string;
}

export interface ProfileDefaults {
  retry?: number;
  timeout?: number;
  skip_if_installed?: boolean;
}

export interface BootstrapConfig {
  homebrew?: boolean;
  mas?: boolean;
}

export interface ProfileMeta {
  name?: string;
  description?: string;
  author?: string;
}

export interface UserProfile {
  version: 1;
  meta?: ProfileMeta;
  defaults?: ProfileDefaults;
  bootstrap?: BootstrapConfig;
  apps: AppEntry[];
  groups?: Record<string, string[]>;
}
