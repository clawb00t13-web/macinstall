'use client'

import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'

interface ProfileEditorProps {
  userId: string
  initialYaml: string
}

export default function ProfileEditor({ userId, initialYaml }: ProfileEditorProps) {
  const [yaml, setYaml] = useState(initialYaml)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState<string | null>(null)

  const handleSave = async () => {
    setSaving(true)
    setMessage(null)

    const supabase = createClient()
    const { error } = await supabase.from('user_profiles').upsert({
      user_id: userId,
      profile_yaml: yaml,
      updated_at: new Date().toISOString(),
    })

    setSaving(false)
    setMessage(error ? `Error: ${error.message}` : 'Saved!')
    setTimeout(() => setMessage(null), 3000)
  }

  return (
    <div className="flex flex-col gap-4">
      <textarea
        value={yaml}
        onChange={(e) => setYaml(e.target.value)}
        className="w-full h-96 bg-[#111] border border-[#333] rounded-lg p-4 font-mono text-sm text-[#f5f5f5] resize-y focus:outline-none focus:border-blue-500"
        placeholder="# Your macinstall profile YAML&#10;apps:&#10;  - homebrew&#10;  - vscode"
        spellCheck={false}
      />
      <div className="flex items-center gap-4">
        <button
          onClick={handleSave}
          disabled={saving}
          className="bg-blue-500 hover:bg-blue-600 disabled:opacity-50 text-white font-medium px-5 py-2 rounded-lg transition-colors"
        >
          {saving ? 'Saving…' : 'Save'}
        </button>
        {message && (
          <span className={`text-sm ${message.startsWith('Error') ? 'text-red-400' : 'text-green-400'}`}>
            {message}
          </span>
        )}
      </div>
    </div>
  )
}
