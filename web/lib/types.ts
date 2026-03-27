export interface UserProfile {
  id: string
  user_id: string
  profile_yaml: string
  installed_app_ids: string[]
  uninstall_queue: string[]
  updated_at: string
}
