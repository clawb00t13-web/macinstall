'use client'

import { useState } from 'react'
import { type StarterPack } from '@/lib/starterPacks'
import { APPS } from '@/lib/catalog'

interface StarterPackCardProps {
  pack: StarterPack
  installedSet: Set<string>
  onApply: (appIds: string[]) => void
  isCustom?: boolean
  onDelete?: () => void
}

export default function StarterPackCard({ pack, installedSet, onApply, isCustom, onDelete }: StarterPackCardProps) {
  const [open, setOpen] = useState(false)
  const [selected, setSelected] = useState<Set<string>>(new Set(pack.appIds))
  const [applied, setApplied] = useState(false)
  const [confirmingDelete, setConfirmingDelete] = useState(false)

  function openModal() {
    setSelected(new Set(pack.appIds))
    setOpen(true)
  }

  function toggle(id: string) {
    setSelected(prev => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  function handleApply() {
    onApply(Array.from(selected))
    setApplied(true)
    setOpen(false)
    setTimeout(() => setApplied(false), 3000)
  }

  const apps = pack.appIds.map(id => APPS.find(a => a.id === id)).filter(Boolean) as typeof APPS

  return (
    <>
      <div className="bg-[#111] border border-[#222] rounded-xl p-5 flex flex-col gap-3">
        {/* Card header row */}
        <div className="flex items-start gap-4">
          <div className="text-3xl flex-shrink-0">{pack.icon}</div>
          <div className="flex-1 min-w-0">
            <h3 className="text-[#f5f5f5] font-semibold text-base">{pack.name}</h3>
            <p className="text-[#888] text-xs mt-1 leading-relaxed">{pack.description}</p>
            <div className="flex items-center justify-between mt-3">
              <span className="text-[#555] text-xs">{pack.appIds.length} apps</span>
              <button
                onClick={openModal}
                className={`text-white text-xs font-medium px-4 py-1.5 rounded-lg transition-colors ${
                  applied ? 'bg-green-600 hover:bg-green-700' : 'bg-blue-500 hover:bg-blue-600'
                }`}
              >
                {applied ? '✓ Applied' : 'Use This Pack'}
              </button>
            </div>
          </div>
          {/* Delete button for custom packs */}
          {isCustom && (
            <button
              onClick={() => setConfirmingDelete(prev => !prev)}
              className="text-[#444] hover:text-[#888] transition-colors text-sm leading-none flex-shrink-0 mt-0.5"
              aria-label="Delete pack"
            >
              ✕
            </button>
          )}
        </div>

        {/* Inline delete confirmation */}
        {isCustom && confirmingDelete && (
          <div className="flex items-center gap-2 pt-1 border-t border-[#1a1a1a]">
            <span className="text-[#888] text-xs flex-1">Delete this pack?</span>
            <button
              onClick={() => { onDelete?.(); setConfirmingDelete(false) }}
              className="text-red-400 hover:text-red-300 text-xs font-medium transition-colors px-2 py-1 rounded"
            >
              Delete
            </button>
            <button
              onClick={() => setConfirmingDelete(false)}
              className="text-[#666] hover:text-[#999] text-xs transition-colors px-2 py-1 rounded"
            >
              Cancel
            </button>
          </div>
        )}
      </div>

      {/* Modal overlay */}
      {open && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
          onClick={(e) => { if (e.target === e.currentTarget) setOpen(false) }}
        >
          <div className="bg-[#111] border border-[#222] rounded-2xl w-full max-w-md mx-4 shadow-2xl flex flex-col max-h-[85vh]">
            {/* Header */}
            <div className="flex items-center gap-3 px-5 pt-5 pb-4 border-b border-[#1a1a1a]">
              <span className="text-2xl">{pack.icon}</span>
              <div className="flex-1 min-w-0">
                <h2 className="text-[#f5f5f5] font-semibold text-base">{pack.name}</h2>
                <p className="text-[#666] text-xs truncate">{pack.description}</p>
              </div>
              <button
                onClick={() => setOpen(false)}
                className="text-[#555] hover:text-[#999] transition-colors text-lg leading-none ml-2"
                aria-label="Close"
              >
                ✕
              </button>
            </div>

            {/* Select all / none */}
            <div className="flex items-center justify-between px-5 py-2.5 border-b border-[#1a1a1a]">
              <div className="flex items-center gap-3">
                <button
                  onClick={() => setSelected(new Set(pack.appIds))}
                  className="text-blue-400 hover:text-blue-300 text-xs transition-colors"
                >
                  Select all
                </button>
                <span className="text-[#333]">·</span>
                <button
                  onClick={() => setSelected(new Set())}
                  className="text-blue-400 hover:text-blue-300 text-xs transition-colors"
                >
                  Deselect all
                </button>
              </div>
              <span className="text-[#555] text-xs">{selected.size} of {pack.appIds.length} selected</span>
            </div>

            {/* App list */}
            <div className="overflow-y-auto flex-1">
              {apps.map(app => {
                const isSelected = selected.has(app.id)
                const isInstalled = installedSet.has(app.id)
                return (
                  <div
                    key={app.id}
                    onClick={() => toggle(app.id)}
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
                onClick={() => setOpen(false)}
                className="text-[#666] hover:text-[#999] text-sm transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleApply}
                disabled={selected.size === 0}
                className="bg-blue-500 hover:bg-blue-600 disabled:opacity-40 disabled:cursor-not-allowed text-white text-sm font-medium px-5 py-2 rounded-lg transition-colors"
              >
                Apply {selected.size} App{selected.size !== 1 ? 's' : ''}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
