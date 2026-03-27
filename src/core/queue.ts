import { AppEntry } from '../types/profile.js';
import { InstallResult, InstallEvent, RetryPolicy } from '../types/installer.js';
import { isAppInstalled, resolveApp } from './detector.js';
import { getInstallerForApp } from '../installers/index.js';
import { DEFAULT_RETRY, DEFAULT_SKIP_IF_INSTALLED } from '../config/defaults.js';

export type EventHandler = (event: InstallEvent) => void;

export interface QueueOptions {
  skipIfInstalled?: boolean;
  defaultRetry?: number;
  onEvent?: EventHandler;
  dryRun?: boolean;
}

export async function runQueue(
  apps: AppEntry[],
  opts: QueueOptions = {}
): Promise<InstallResult[]> {
  const {
    skipIfInstalled = DEFAULT_SKIP_IF_INSTALLED,
    defaultRetry = DEFAULT_RETRY,
    onEvent,
    dryRun = false,
  } = opts;

  const results: InstallResult[] = [];

  for (const app of apps) {
    const emit = (event: InstallEvent) => onEvent?.(event);

    emit({ type: 'start', appId: app.id, appName: app.name });

    // Resolve 'auto' method via catalog
    const resolvedApp = resolveApp(app);
    if (!resolvedApp) {
      const result: InstallResult = {
        appId: app.id,
        appName: app.name,
        status: 'failed',
        method: 'auto',
        duration: 0,
        attempts: 0,
        error: `Could not resolve method for "${app.name}": not found in catalog`,
      };
      results.push(result);
      emit({ type: 'error', appId: app.id, appName: app.name, result });
      continue;
    }

    // Skip check
    if (skipIfInstalled) {
      const installed = await isAppInstalled(app);
      if (installed) {
        const result: InstallResult = {
          appId: app.id,
          appName: app.name,
          status: 'skipped',
          method: resolvedApp.method,
          duration: 0,
          attempts: 0,
        };
        results.push(result);
        emit({ type: 'skip', appId: app.id, appName: app.name, result });
        continue;
      }
    }

    if (dryRun) {
      const result: InstallResult = {
        appId: app.id,
        appName: app.name,
        status: 'pending',
        method: resolvedApp.method,
        duration: 0,
        attempts: 0,
      };
      results.push(result);
      continue;
    }

    // Install with retry
    const maxAttempts = (app.retry ?? defaultRetry) + 1;
    const policy: RetryPolicy = {
      maxAttempts,
      delayMs: 2000,
      backoffMultiplier: 2,
    };

    const result = await installWithRetry(resolvedApp, policy, emit);
    results.push(result);

    if (result.status === 'installed') {
      emit({ type: 'complete', appId: app.id, appName: app.name, result });
    } else {
      emit({ type: 'error', appId: app.id, appName: app.name, result });
    }
  }

  return results;
}

async function installWithRetry(
  app: AppEntry,
  policy: RetryPolicy,
  emit: EventHandler
): Promise<InstallResult> {
  const installer = getInstallerForApp(app);
  let lastResult: InstallResult | null = null;
  let delayMs = policy.delayMs;

  for (let attempt = 1; attempt <= policy.maxAttempts; attempt++) {
    if (attempt > 1) {
      emit({
        type: 'retry',
        appId: app.id,
        appName: app.name,
        attempt,
        message: `Retrying (attempt ${attempt}/${policy.maxAttempts})...`,
      });
      await sleep(delayMs);
      delayMs = Math.floor(delayMs * policy.backoffMultiplier);
    }

    lastResult = await installer.install(app);
    lastResult.attempts = attempt;

    if (lastResult.status === 'installed') {
      return lastResult;
    }
  }

  return lastResult!;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
