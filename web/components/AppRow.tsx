'use client'

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
  enabled: boolean
  installed: boolean
  onToggle: (id: string, value: boolean) => void
}

export default function AppRow({ app, enabled, installed, onToggle }: AppRowProps) {
  const method = getInstallMethod(app)
  const badge = method ? BADGE[method] : null
  const letter = app.name.charAt(0).toUpperCase()
  const color = letterColor(app.name)

  return (
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
          {badge && (
            <span className={`${badge.className} text-[10px] font-medium px-1.5 py-0.5 rounded-full flex-shrink-0`}>
              {badge.label}
            </span>
          )}
        </div>
        <p className="text-[#888] text-xs truncate mt-0.5">{app.description}</p>
      </div>

      {/* Toggle */}
      <button
        role="switch"
        aria-checked={enabled}
        onClick={() => onToggle(app.id, !enabled)}
        className={`relative w-10 h-6 rounded-full transition-colors flex-shrink-0 ${enabled ? 'bg-blue-500' : 'bg-[#333]'}`}
      >
        <span
          className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${enabled ? 'translate-x-4' : 'translate-x-0'}`}
        />
      </button>
    </div>
  )
}
