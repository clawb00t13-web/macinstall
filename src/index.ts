// Public API — for use as a library
export { loadProfile, validateProfile } from './config/loader.js';
export { runInstall } from './core/installer.js';
export { bootstrap } from './core/bootstrap.js';
export { runQueue } from './core/queue.js';
export { findById, findByName, search } from './catalog/index.js';

export type { UserProfile, AppEntry, InstallMethod } from './types/profile.js';
export type { InstallResult, InstallEvent } from './types/installer.js';
export type { InstallSummary } from './core/installer.js';
