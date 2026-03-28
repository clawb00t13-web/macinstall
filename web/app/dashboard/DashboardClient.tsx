'use client'

import { useState, useCallback, useRef, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'
import { APPS, CATEGORIES } from '@/lib/catalog'
import { STARTER_PACKS } from '@/lib/starterPacks'
import { parseProfileYaml, serializeProfileYaml, type ProfileState } from '@/lib/profileYaml'
import AppRow from '@/components/AppRow'
import CategoryPills from '@/components/CategoryPills'
import StarterPackCard from '@/components/StarterPackCard'
import PackCreateModal from '@/components/PackCreateModal'
import dynamic from 'next/dynamic'
import type { CustomPack } from '@/lib/types'

const SignOutButton = dynamic(() => import('@/components/SignOutButton'), { ssr: false })

interface DashboardClientProps {
  userId: string
  userEmail: string | undefined
  initialYaml: string
  installedAppIds: string[]
  initialCustomPacks: CustomPack[]
  initialAppliedPackId: string | null
}

type Tab = 'apps' | 'packs'

export default function DashboardClient({ userId, userEmail, initialYaml, installedAppIds, initialCustomPacks, initialAppliedPackId }: DashboardClientProps) {
  const [installedSet, setInstalledSet] = useState(() => new Set(installedAppIds))
  const [tab, setTab] = useState<Tab>('apps')
  const [category, setCategory] = useState('all')
  const [search, setSearch] = useState('')
  const [profile, setProfile] = useState<ProfileState>(() => parseProfileYaml(initialYaml))
  const [customPacks, setCustomPacks] = useState<CustomPack[]>(initialCustomPacks)
  const [appliedPackId, setAppliedPackId] = useState<string | null>(initialAppliedPackId)
  const [showCreateModal, setShowCreateModal] = useState(false)
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  useEffect(() => {
    const supabase = createClient()
    const poll = async () => {
      const { data } = await supabase
        .from('user_profiles')
        .select('installed_app_ids, applied_pack_id')
        .eq('user_id', userId)
        .single()
      if (data?.installed_app_ids) {
        setInstalledSet(prev => {
          const next = new Set<string>(data.installed_app_ids)
          if (next.size === prev.size && [...next].every(id => prev.has(id))) return prev
          return next
        })
      }
      if (data?.applied_pack_id) {
        setAppliedPackId(prev => prev === data.applied_pack_id ? prev : data.applied_pack_id)
      }
    }
    const interval = setInterval(poll, 5000)
    return () => clearInterval(interval)
  }, [userId])

  const persist = useCallback(async (state: ProfileState) => {
    const supabase = createClient()
    await supabase.from('user_profiles').upsert({
      user_id: userId,
      profile_yaml: serializeProfileYaml(state),
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })
  }, [userId])

  const persistCustomPacks = useCallback(async (packs: CustomPack[]) => {
    const supabase = createClient()
    await supabase.from('user_profiles').upsert({
      user_id: userId,
      custom_packs: packs,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })
  }, [userId])

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

  const handleApplyPack = useCallback((appIds: string[], packId: string) => {
    setAppliedPackId(packId)
    setProfile((prev) => {
      const next = { ...prev }
      for (const id of appIds) next[id] = true
      if (debounceRef.current) clearTimeout(debounceRef.current)
      debounceRef.current = setTimeout(() => persist(next), 800)
      return next
    })
    const supabase = createClient()
    supabase.from('user_profiles').upsert({
      user_id: userId,
      applied_pack_id: packId,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })
  }, [persist, userId])

  const handleCreatePack = useCallback((data: Omit<CustomPack, 'id'>) => {
    const newPack: CustomPack = { id: crypto.randomUUID(), ...data }
    setCustomPacks(prev => {
      const next = [newPack, ...prev]
      persistCustomPacks(next)
      return next
    })
    setShowCreateModal(false)
  }, [persistCustomPacks])

  const handleDeletePack = useCallback((id: string) => {
    setCustomPacks(prev => {
      const next = prev.filter(p => p.id !== id)
      persistCustomPacks(next)
      return next
    })
  }, [persistCustomPacks])

  const filtered = APPS.filter((app) => {
    const matchCat = category === 'all' || app.categories.includes(category)
    const matchSearch = search === '' ||
      app.name.toLowerCase().includes(search.toLowerCase()) ||
      app.description.toLowerCase().includes(search.toLowerCase())
    return matchCat && matchSearch
  })

  // Merge custom packs into a StarterPack-compatible shape for StarterPackCard
  const customPacksAsStarter = customPacks.map(cp => ({
    id: cp.id,
    name: cp.name,
    description: cp.description,
    tagline: cp.description,
    icon: cp.icon,
    appIds: cp.appIds,
  }))

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
                    installed={installedSet.has(app.id)}
                    onUninstall={handleUninstall}
                  />
                ))
              )}
            </div>

          </>
        ) : (
          <>
            {/* New Pack button */}
            <div className="flex justify-end mb-4">
              <button
                onClick={() => setShowCreateModal(true)}
                className="bg-[#1a1a1a] hover:bg-[#222] border border-[#333] text-[#f5f5f5] text-xs font-medium px-4 py-2 rounded-lg transition-colors"
              >
                + New Pack
              </button>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              {/* Custom packs first */}
              {customPacksAsStarter.map((pack) => (
                <StarterPackCard
                  key={pack.id}
                  pack={pack}
                  installedSet={installedSet}
                  isApplied={appliedPackId === pack.id}
                  onApply={handleApplyPack}
                  isCustom={true}
                  onDelete={() => handleDeletePack(pack.id)}
                />
              ))}
              {/* Built-in packs */}
              {STARTER_PACKS.map((pack) => (
                <StarterPackCard
                  key={pack.id}
                  pack={pack}
                  installedSet={installedSet}
                  isApplied={appliedPackId === pack.id}
                  onApply={handleApplyPack}
                />
              ))}
            </div>
          </>
        )}
      </main>

      {/* Create pack modal */}
      {showCreateModal && (
        <PackCreateModal
          installedSet={installedSet}
          onSave={handleCreatePack}
          onClose={() => setShowCreateModal(false)}
        />
      )}
    </div>
  )
}
