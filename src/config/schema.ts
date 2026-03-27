import { z } from 'zod';

export const InstallMethodSchema = z.enum([
  'brew-cask',
  'brew-formula',
  'mas',
  'dmg',
  'script',
  'auto',
]);

export const AppOptionsSchema = z.object({
  version: z.string().optional(),
  mas_id: z.number().int().positive().optional(),
  url: z.string().url().optional(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/i).optional(),
  app_name: z.string().optional(),
  script: z.string().optional(),
  check_command: z.string().optional(),
}).optional();

export const AppEntrySchema = z.object({
  id: z.string().min(1),
  name: z.string().min(1),
  method: InstallMethodSchema,
  options: AppOptionsSchema,
  retry: z.number().int().min(0).max(5).optional(),
  timeout: z.number().int().positive().optional(),
  optional: z.boolean().optional(),
  note: z.string().optional(),
}).refine(
  (app) => {
    if (app.method === 'dmg') {
      return app.options?.url !== undefined;
    }
    return true;
  },
  { message: 'DMG install method requires options.url' }
).refine(
  (app) => {
    if (app.method === 'script') {
      return app.options?.script !== undefined;
    }
    return true;
  },
  { message: 'Script install method requires options.script' }
);

export const ProfileDefaultsSchema = z.object({
  retry: z.number().int().min(0).max(5).optional(),
  timeout: z.number().int().positive().optional(),
  skip_if_installed: z.boolean().optional(),
});

export const BootstrapConfigSchema = z.object({
  homebrew: z.boolean().optional(),
  mas: z.boolean().optional(),
});

export const ProfileMetaSchema = z.object({
  name: z.string().optional(),
  description: z.string().optional(),
  author: z.string().optional(),
});

export const UserProfileSchema = z.object({
  version: z.literal(1),
  meta: ProfileMetaSchema.optional(),
  defaults: ProfileDefaultsSchema.optional(),
  bootstrap: BootstrapConfigSchema.optional(),
  apps: z.array(AppEntrySchema).min(1),
  groups: z.record(z.string(), z.array(z.string())).optional(),
}).refine(
  (profile) => {
    if (!profile.groups) return true;
    const appIds = new Set(profile.apps.map((a) => a.id));
    for (const [groupName, ids] of Object.entries(profile.groups)) {
      for (const id of ids) {
        if (!appIds.has(id)) {
          return false;
        }
      }
    }
    return true;
  },
  { message: 'All group app IDs must reference apps defined in the apps array' }
);

export type ValidatedProfile = z.infer<typeof UserProfileSchema>;
export type ValidatedAppEntry = z.infer<typeof AppEntrySchema>;
