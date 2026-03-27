'use client'

import { type StarterPack } from '@/lib/starterPacks'

interface StarterPackCardProps {
  pack: StarterPack
  onApply: (appIds: string[]) => void
}

export default function StarterPackCard({ pack, onApply }: StarterPackCardProps) {
  return (
    <div className="bg-[#111] border border-[#222] rounded-xl p-5 flex items-start gap-4">
      <div className="text-3xl flex-shrink-0">{pack.icon}</div>
      <div className="flex-1 min-w-0">
        <h3 className="text-[#f5f5f5] font-semibold text-base">{pack.name}</h3>
        <p className="text-[#888] text-xs mt-1 leading-relaxed">{pack.description}</p>
        <div className="flex items-center justify-between mt-3">
          <span className="text-[#555] text-xs">{pack.appIds.length} apps</span>
          <button
            onClick={() => onApply(pack.appIds)}
            className="bg-blue-500 hover:bg-blue-600 text-white text-xs font-medium px-4 py-1.5 rounded-lg transition-colors"
          >
            Apply
          </button>
        </div>
      </div>
    </div>
  )
}
