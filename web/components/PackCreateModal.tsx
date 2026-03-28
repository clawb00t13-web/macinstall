'use client'

import { useState } from 'react'
import { APPS } from '@/lib/catalog'
import type { CustomPack } from '@/lib/types'

interface PackCreateModalProps {
  installedSet: Set<string>
  onSave: (pack: Omit<CustomPack, 'id'>) => void
  onClose: () => void
}

export default function PackCreateModal({ installedSet, onSave, onClose }: PackCreateModalProps) {
  const [icon, setIcon] = useState('🚀')
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [selectedAppIds, setSelectedAppIds] = useState<Set<string>>(new Set())
  const [appSearch, setAppSearch] = useState('')

  function toggleApp(id: string) {
    setSelectedAppIds(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  function handleIconChange(value: string) {
    // Keep only the last character typed (to allow replacing the emoji)
    const chars = [...value]
    if (chars.length === 0) {
      setIcon('')
    } else {
      setIcon(chars[chars.length - 1])
    }
  }

  function handleCreate() {
    if (!name.trim() || selectedAppIds.size === 0) return
    onSave({
      name: name.trim(),
      description: description.trim(),
      icon: icon || '📦',
      appIds: Array.from(selectedAppIds),
    })
  }

  const filteredApps = APPS.filter(app =>
    appSearch === '' ||
    app.name.toLowerCase().includes(appSearch.toLowerCase()) ||
    app.description.toLowerCase().includes(appSearch.toLowerCase())
  )

  const canCreate = name.trim().length > 0 && selectedAppIds.size > 0

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div className="bg-[#111] border border-[#222] rounded-2xl w-full max-w-md mx-4 shadow-2xl flex flex-col max-h-[90vh]">
        {/* Header */}
        <div className="flex items-center justify-between px-5 pt-5 pb-4 border-b border-[#1a1a1a]">
          <h2 className="text-[#f5f5f5] font-semibold text-base">New Pack</h2>
          <button
            onClick={onClose}
            className="text-[#555] hover:text-[#999] transition-colors text-lg leading-none"
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        {/* Form fields */}
        <div className="px-5 py-4 border-b border-[#1a1a1a] flex flex-col gap-3">
          <div className="flex items-center gap-3">
            {/* Emoji input */}
            <input
              type="text"
              value={icon}
              onChange={(e) => handleIconChange(e.target.value)}
              placeholder="🚀"
              className="w-12 h-10 bg-[#1a1a1a] border border-[#333] rounded-lg text-center text-xl focus:outline-none focus:border-blue-500 transition-colors"
            />
            {/* Name */}
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Pack name"
              className="flex-1 bg-[#1a1a1a] border border-[#333] rounded-lg px-3 py-2 text-sm text-[#f5f5f5] placeholder-[#555] focus:outline-none focus:border-blue-500 transition-colors"
            />
          </div>
          {/* Description */}
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Description (optional)"
            rows={2}
            className="bg-[#1a1a1a] border border-[#333] rounded-lg px-3 py-2 text-sm text-[#f5f5f5] placeholder-[#555] focus:outline-none focus:border-blue-500 transition-colors resize-none"
          />
        </div>

        {/* App selection header + search */}
        <div className="px-5 py-3 border-b border-[#1a1a1a] flex flex-col gap-2">
          <div className="flex items-center justify-between">
            <span className="text-[#999] text-xs font-medium uppercase tracking-wide">Add Apps</span>
            <span className="text-[#555] text-xs">{selectedAppIds.size} selected</span>
          </div>
          <input
            type="text"
            value={appSearch}
            onChange={(e) => setAppSearch(e.target.value)}
            placeholder="Search apps…"
            className="bg-[#1a1a1a] border border-[#333] rounded-lg px-3 py-2 text-sm text-[#f5f5f5] placeholder-[#555] focus:outline-none focus:border-blue-500 transition-colors"
          />
        </div>

        {/* App list */}
        <div className="overflow-y-auto flex-1">
          {filteredApps.map(app => {
            const isSelected = selectedAppIds.has(app.id)
            const isInstalled = installedSet.has(app.id)
            return (
              <div
                key={app.id}
                onClick={() => toggleApp(app.id)}
                className={`flex items-center gap-3 px-5 py-3 cursor-pointer border-b border-[#1a1a1a] last:border-0 transition-colors hover:bg-white/[0.03] ${
                  isSelected ? '' : 'opacity-40'
                }`}
              >
                {/* Checkbox */}
                <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center flex-shrink-0 transition-colors ${
                  isSelected ? 'bg-blue-500 border-blue-500' : 'border-[#444]'
                }`}>
                  {isSelected && (
                    <svg width="10" height="8" viewBox="0 0 10 8" fill="none">
                      <path d="M1 4l2.5 2.5L9 1" stroke="white" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                    </svg>
                  )}
                </div>

                {/* Letter icon */}
                <div className="w-8 h-8 rounded-lg bg-[#1a1a1a] flex items-center justify-center flex-shrink-0 text-[#888] font-semibold text-sm">
                  {app.name.charAt(0)}
                </div>

                {/* Name + description */}
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2">
                    <span className="text-[#f5f5f5] text-sm font-medium truncate">{app.name}</span>
                    {isInstalled && (
                      <span className="bg-green-900/50 text-green-400 text-[10px] font-medium px-1.5 py-0.5 rounded-full flex-shrink-0">
                        ✓ Installed
                      </span>
                    )}
                  </div>
                  <p className="text-[#666] text-xs truncate">{app.description}</p>
                </div>
              </div>
            )
          })}
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between gap-3 px-5 py-4 border-t border-[#1a1a1a]">
          <button
            onClick={onClose}
            className="text-[#666] hover:text-[#999] text-sm transition-colors"
          >
            Cancel
          </button>
          <button
            onClick={handleCreate}
            disabled={!canCreate}
            className="bg-blue-500 hover:bg-blue-600 disabled:opacity-40 disabled:cursor-not-allowed text-white text-sm font-medium px-5 py-2 rounded-lg transition-colors"
          >
            Create Pack
          </button>
        </div>
      </div>
    </div>
  )
}
