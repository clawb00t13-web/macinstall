import * as fs from 'fs';
import * as path from 'path';
import { parse as parseYaml } from 'yaml';
import { UserProfileSchema, ValidatedProfile } from './schema.js';
import { DEFAULT_PROFILE_PATHS } from './defaults.js';

export class ProfileLoadError extends Error {
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = 'ProfileLoadError';
  }
}

export class ProfileValidationError extends Error {
  constructor(message: string, public readonly issues: string[]) {
    super(message);
    this.name = 'ProfileValidationError';
  }
}

export function loadProfile(filePath?: string): ValidatedProfile {
  const resolvedPath = filePath
    ? path.resolve(filePath)
    : findDefaultProfile();

  if (!resolvedPath) {
    throw new ProfileLoadError(
      `No profile found. Create ~/.macinstall.yml or pass a path with --profile.\n` +
      `Checked: ${DEFAULT_PROFILE_PATHS.join(', ')}`
    );
  }

  let raw: string;
  try {
    raw = fs.readFileSync(resolvedPath, 'utf8');
  } catch (err) {
    throw new ProfileLoadError(`Cannot read profile at ${resolvedPath}`, err);
  }

  let parsed: unknown;
  try {
    const ext = path.extname(resolvedPath).toLowerCase();
    if (ext === '.json') {
      parsed = JSON.parse(raw);
    } else {
      parsed = parseYaml(raw);
    }
  } catch (err) {
    throw new ProfileLoadError(`Failed to parse profile at ${resolvedPath}`, err);
  }

  return validateProfile(parsed);
}

export function validateProfile(data: unknown): ValidatedProfile {
  const result = UserProfileSchema.safeParse(data);
  if (!result.success) {
    const issues = result.error.issues.map(
      (i) => `  ${i.path.join('.')}: ${i.message}`
    );
    throw new ProfileValidationError(
      `Profile validation failed:\n${issues.join('\n')}`,
      issues
    );
  }
  return result.data;
}

function findDefaultProfile(): string | null {
  for (const p of DEFAULT_PROFILE_PATHS) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}
