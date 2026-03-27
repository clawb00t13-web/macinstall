import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import type { UserProfile } from '@/lib/types'
import DashboardClient from './DashboardClient'

export default async function DashboardPage() {
  const supabase = createClient()

  const {
    data: { session },
  } = await supabase.auth.getSession()

  if (!session) {
    redirect('/')
  }

  const { data: profile } = await supabase
    .from('user_profiles')
    .select('*')
    .eq('user_id', session.user.id)
    .single<UserProfile>()

  return (
    <DashboardClient
      userId={session.user.id}
      userEmail={session.user.email}
      initialYaml={profile?.profile_yaml ?? ''}
      installedAppIds={profile?.installed_app_ids ?? []}
    />
  )
}
