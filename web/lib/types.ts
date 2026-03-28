export interface CustomPack {
  id: string
  name: string
  description: string
  icon: string
  appIds: string[]
}

export interface UserProfile {
  id: string
  user_id: string
  profile_yaml: string
  installed_app_ids: string[]
  uninstall_queue: string[]
  custom_packs: CustomPack[]
  applied_pack_id: string | null
  app_configs: Record<string, Record<string, string>> | null
  updated_at: string
}
