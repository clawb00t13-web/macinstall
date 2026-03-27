import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'
import type { UserProfile } from '@/lib/types'
import ProfileEditor from './ProfileEditor'

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
    <div className="max-w-2xl mx-auto px-4 py-8">
      <header className="flex items-center justify-between mb-8">
        <div className="flex items-center gap-2">
          <span className="text-2xl">⬇</span>
          <span className="font-semibold">MacInstall</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-[#888] text-sm">{session.user.email}</span>
          <SignOutButtonWrapper />
        </div>
      </header>

      <h1 className="text-2xl font-bold mb-6">My Profile</h1>

      <ProfileEditor
        userId={session.user.id}
        initialYaml={profile?.profile_yaml ?? ''}
      />
    </div>
  )
}

// Dynamic import to keep server component boundary clean
import dynamic from 'next/dynamic'
const SignOutButtonWrapper = dynamic(
  () => import('@/components/SignOutButton'),
  { ssr: false }
)
