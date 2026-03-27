'use client'

import { useState, useCallback, useRef } from 'react'
import { createClient } from '@/lib/supabase/client'
import { APPS, CATEGORIES } from '@/lib/catalog'
import { STARTER_PACKS } from '@/lib/starterPacks'
import { parseProfileYaml, serializeProfileYaml, type ProfileState } from '@/lib/profileYaml'
import AppRow from '@/components/AppRow'
import CategoryPills from '@/components/CategoryPills'
import StarterPackCard from '@/components/StarterPackCard'
import dynamic from 'next/dynamic'

const SignOutButton = dynamic(() => import('@/components/SignOutButton'), { ssr: false })

interface DashboardClientProps {
  userId: string
  userEmail: string | undefined
  initialYaml: string
  installedAppIds: string[]
}

type Tab = 'apps' | 'packs'

export default function DashboardClient({ userId, userEmail, initialYaml, installedAppIds }: DashboardClientProps) {
  const installedSet = new Set(installedAppIds)
  const [tab, setTab] = useState<Tab>('apps')
  const [category, setCategory] = useState('all')
  const [search, setSearch] = useState('')
  const [profile, setProfile] = useState<ProfileState>(() => parseProfileYaml(initialYaml))
  const [saveStatus, setSaveStatus] = useState<'idle' | 'saving' | 'saved' | 'error'>('idle')
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const persist = useCallback(async (state: ProfileState) => {
    setSaveStatus('saving')
    const supabase = createClient()
    const { error } = await supabase.from('user_profiles').upsert({
      user_id: userId,
      profile_yaml: serializeProfileYaml(state),
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })
    setSaveStatus(error ? 'error' : 'saved')
    setTimeout(() => setSaveStatus('idle'), 2000)
  }, [userId])

  const handleToggle = useCallback((id: string, value: boolean) => {
    setProfile((prev) => {
      const next = { ...prev, [id]: value }
      if (debounceRef.current) clearTimeout(debounceRef.current)
      debounceRef.current = setTimeout(() => persist(next), 800)
      return next
    })
  }, [persist])

  const handleUninstall = useCallback(async (id: string) => {
    const supabase = createClient()
    const { data } = await supabase
      .from('user_profiles')
      .select('uninstall_queue')
      .eq('user_id', userId)
      .single()
    const current: string[] = data?.uninstall_queue ?? []
    if (!current.includes(id)) {
      await supabase.from('user_profiles').upsert({
        user_id: userId,
        uninstall_queue: [...current, id],
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' })
    }
  }, [userId])

  const handleApplyPack = useCallback((appIds: string[]) => {
    setProfile((prev) => {
      const next = { ...prev }
      for (const id of appIds) next[id] = true
      if (debounceRef.current) clearTimeout(debounceRef.current)
      debounceRef.current = setTimeout(() => persist(next), 800)
      return next
    })
  }, [persist])

  const handleSave = useCallback(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current)
    persist(profile)
  }, [persist, profile])

  const filtered = APPS.filter((app) => {
    const matchCat = category === 'all' || app.categories.includes(category)
    const matchSearch = search === '' ||
      app.name.toLowerCase().includes(search.toLowerCase()) ||
      app.description.toLowerCase().includes(search.toLowerCase())
    return matchCat && matchSearch
  })

  const enabledCount = Object.values(profile).filter(Boolean).length

  return (
    <div className="min-h-screen bg-[#0a0a0a] text-[#f5f5f5]">
      {/* Header */}
      <header className="border-b border-[#1a1a1a] sticky top-0 bg-[#0a0a0a]/90 backdrop-blur z-10">
        <div className="max-w-[900px] mx-auto px-4 h-14 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <span className="text-lg font-bold">MacInstall</span>
          </div>

          {/* Tabs */}
          <div className="flex bg-[#111] rounded-full p-0.5 gap-0.5">
            {(['apps', 'packs'] as const).map((t) => (
              <button
                key={t}
                onClick={() => setTab(t)}
                className={`px-4 py-1.5 rounded-full text-xs font-medium transition-colors ${
                  tab === t ? 'bg-[#222] text-[#f5f5f5]' : 'text-[#666] hover:text-[#999]'
                }`}
              >
                {t === 'apps' ? 'Apps' : 'Starter Packs'}
              </button>
            ))}
          </div>

          {/* User */}
          <div className="flex items-center gap-3">
            <span className="text-[#555] text-xs hidden sm:block">{userEmail}</span>
            <SignOutButton />
          </div>
        </div>
      </header>

      {/* Content */}
      <main className="max-w-[900px] mx-auto px-4 py-6">
        {tab === 'apps' ? (
          <>
            {/* Search */}
            <div className="mb-4">
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Search apps…"
                className="w-full bg-[#111] border border-[#222] rounded-xl px-4 py-2.5 text-sm text-[#f5f5f5] placeholder-[#555] focus:outline-none focus:border-blue-500 transition-colors"
              />
            </div>

            {/* Category pills */}
            <div className="mb-4">
              <CategoryPills categories={CATEGORIES} selected={category} onSelect={setCategory} />
            </div>

            {/* App list */}
            <div className="bg-[#0f0f0f] border border-[#1a1a1a] rounded-xl overflow-hidden divide-y divide-[#1a1a1a]">
              {filtered.length === 0 ? (
                <div className="py-12 text-center text-[#555] text-sm">No apps match your search.</div>
              ) : (
                filtered.map((app) => (
                  <AppRow
                    key={app.id}
                    app={app}
                    enabled={app.id in profile ? !!profile[app.id] : installedSet.has(app.id)}
                    installed={installedSet.has(app.id)}
                    onToggle={handleToggle}
                    onUninstall={handleUninstall}
                  />
                ))
              )}
            </div>

            {/* Bottom bar */}
            <div className="sticky bottom-0 mt-4 bg-[#0a0a0a]/90 backdrop-blur border-t border-[#1a1a1a] -mx-4 px-4 py-3 flex items-center justify-between">
              <span className="text-[#555] text-sm">{enabledCount} app{enabledCount !== 1 ? 's' : ''} selected</span>
              <div className="flex items-center gap-3">
                {saveStatus === 'saving' && <span className="text-[#888] text-xs">Saving…</span>}
                {saveStatus === 'saved' && <span className="text-green-400 text-xs">Saved</span>}
                {saveStatus === 'error' && <span className="text-red-400 text-xs">Error saving</span>}
                <button
                  onClick={handleSave}
                  disabled={saveStatus === 'saving'}
                  className="bg-blue-500 hover:bg-blue-600 disabled:opacity-50 text-white text-sm font-medium px-5 py-2 rounded-lg transition-colors"
                >
                  Save Profile
                </button>
              </div>
            </div>
          </>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {STARTER_PACKS.map((pack) => (
              <StarterPackCard
                key={pack.id}
                pack={pack}
                onApply={handleApplyPack}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  )
}
