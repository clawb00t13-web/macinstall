'use client'

import { type Category } from '@/lib/catalog'

interface CategoryPillsProps {
  categories: Category[]
  selected: string
  onSelect: (id: string) => void
}

export default function CategoryPills({ categories, selected, onSelect }: CategoryPillsProps) {
  return (
    <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-hide">
      {categories.map((cat) => (
        <button
          key={cat.id}
          onClick={() => onSelect(cat.id)}
          className={`flex-shrink-0 px-3 py-1.5 rounded-full text-xs font-medium transition-colors ${
            selected === cat.id
              ? 'bg-blue-500 text-white'
              : 'bg-[#1a1a1a] text-[#888] hover:bg-[#222] hover:text-[#ccc]'
          }`}
        >
          {cat.label}
        </button>
      ))}
    </div>
  )
}
