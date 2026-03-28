'use client'

import { useState } from 'react'
import { type App, getInstallMethod } from '@/lib/catalog'

const LETTER_COLORS = [
  'bg-blue-600', 'bg-purple-600', 'bg-green-600', 'bg-orange-500',
  'bg-pink-600', 'bg-teal-600', 'bg-red-600', 'bg-indigo-600',
  'bg-yellow-600', 'bg-cyan-600',
]

function letterColor(name: string): string {
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) >>> 0
  return LETTER_COLORS[hash % LETTER_COLORS.length]
}

const BADGE: Record<string, { label: string; className: string }> = {
  brew:   { label: 'brew',   className: 'bg-green-900/60 text-green-300' },
  mas:    { label: 'mas',    className: 'bg-blue-900/60 text-blue-300' },
  dmg:    { label: 'dmg',    className: 'bg-orange-900/60 text-orange-300' },
  script: { label: 'script', className: 'bg-purple-900/60 text-purple-300' },
}

interface AppRowProps {
  app: App
  installed: boolean
  onUninstall: (id: string) => void
}

export default function AppRow({ app, installed, onUninstall }: AppRowProps) {
  const method = getInstallMethod(app)
  const badge = method ? BADGE[method] : null
  const letter = app.name.charAt(0).toUpperCase()
  const color = letterColor(app.name)
  const [confirming, setConfirming] = useState(false)
  const [queued, setQueued] = useState(false)

  function handleConfirm() {
    onUninstall(app.id)
    setConfirming(false)
    setQueued(true)
    setTimeout(() => setQueued(false), 2000)
  }

  return (
    <div className="group">
      <div className="flex items-center gap-3 px-4 py-3 hover:bg-white/[0.03] transition-colors">
        {/* Letter icon */}
        <div className={`${color} w-9 h-9 rounded-lg flex items-center justify-center flex-shrink-0 text-white font-semibold text-sm`}>
          {letter}
        </div>

        {/* Name + description */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <span className="text-[#f5f5f5] text-sm font-medium truncate">{app.name}</span>
            {installed && (
              <span className="bg-green-900/50 text-green-400 text-[10px] font-medium px-1.5 py-0.5 rounded-full flex-shrink-0">
                ✓ Installed
              </span>
            )}
            {installed && !queued && (
              <button
                onClick={() => setConfirming(true)}
                className="opacity-0 group-hover:opacity-100 transition-opacity text-[#666] hover:text-red-400 flex-shrink-0"
                aria-label={`Uninstall ${app.name}`}
              >
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                  <polyline points="3 6 5 6 21 6"/>
                  <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>
                  <path d="M10 11v6M14 11v6"/>
                  <path d="M9 6V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2"/>
                </svg>
              </button>
            )}
            {queued && (
              <span className="text-[#888] text-[10px] flex-shrink-0">Queued</span>
            )}
            {badge && (
              <span className={`${badge.className} text-[10px] font-medium px-1.5 py-0.5 rounded-full flex-shrink-0`}>
                {badge.label}
              </span>
            )}
          </div>
          <p className="text-[#888] text-xs truncate mt-0.5">{app.description}</p>
        </div>
      </div>

      {confirming && (
        <div className="flex items-center gap-3 px-4 pb-3 pl-16">
          <span className="text-red-400 text-xs">Remove {app.name} from your Mac?</span>
          <button
            onClick={handleConfirm}
            className="bg-red-600 hover:bg-red-700 text-white text-xs font-medium px-3 py-1 rounded-md transition-colors"
          >
            Confirm
          </button>
          <button
            onClick={() => setConfirming(false)}
            className="text-[#666] hover:text-[#999] text-xs transition-colors"
          >
            Cancel
          </button>
        </div>
      )}
    </div>
  )
}
