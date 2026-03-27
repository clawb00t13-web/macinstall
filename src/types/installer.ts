export type InstallMethod = string;

export type InstallStatus =
  | 'pending'
  | 'running'
  | 'installed'
  | 'skipped'
  | 'failed'
  | 'retrying';

export interface InstallResult {
  appId: string;
  appName: string;
  status: InstallStatus;
  method: string;
  duration: number; // ms
  attempts: number;
  error?: string;
}

export interface RetryPolicy {
  maxAttempts: number;
  delayMs: number;
  backoffMultiplier: number;
}

export interface InstallEvent {
  type: 'start' | 'progress' | 'complete' | 'error' | 'skip' | 'retry';
  appId: string;
  appName: string;
  message?: string;
  result?: InstallResult;
  attempt?: number;
}
