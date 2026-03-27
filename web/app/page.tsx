'use client'

import { useEffect, useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function Home() {
  const router = useRouter()
  const supabase = createClient()
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState<'google' | 'apple' | null>(null)

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session) router.push('/dashboard')
    })
  }, [router, supabase])

  const signInWith = async (provider: 'google' | 'apple') => {
    setError(null)
    setLoading(provider)
    const origin = process.env.NEXT_PUBLIC_SITE_URL ?? window.location.origin
    const { error } = await supabase.auth.signInWithOAuth({
      provider,
      options: {
        redirectTo: `${origin}/auth/callback`,
      },
    })
    if (error) {
      setError(error.message)
      setLoading(null)
    }
  }

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8">
      <div className="flex flex-col items-center gap-3">
        <span className="text-6xl">⬇</span>
        <h1 className="text-4xl font-bold tracking-tight">MacInstall</h1>
        <p className="text-[#888] text-lg">Your Mac setup, everywhere.</p>
      </div>

      <div className="flex flex-col gap-3 w-64">
        <button
          onClick={() => signInWith('google')}
          disabled={!!loading}
          className="flex items-center gap-3 bg-white text-black font-medium px-5 py-3 rounded-lg hover:bg-gray-100 transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
        >
          <GoogleIcon />
          {loading === 'google' ? 'Redirecting…' : 'Sign in with Google'}
        </button>

        <button
          onClick={() => signInWith('apple')}
          disabled={!!loading}
          className="flex items-center gap-3 bg-[#1a1a1a] text-white font-medium px-5 py-3 rounded-lg border border-white/10 hover:bg-[#2a2a2a] transition-colors disabled:opacity-60 disabled:cursor-not-allowed"
        >
          <span className="text-lg leading-none">&#63743;</span>
          {loading === 'apple' ? 'Redirecting…' : 'Sign in with Apple'}
        </button>

        {error && (
          <p className="text-red-400 text-sm text-center">{error}</p>
        )}
      </div>
    </main>
  )
}

function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844c-.209 1.125-.843 2.078-1.796 2.717v2.258h2.908c1.702-1.567 2.684-3.875 2.684-6.615z" fill="#4285F4"/>
      <path d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z" fill="#34A853"/>
      <path d="M3.964 10.71A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.042l3.007-2.332z" fill="#FBBC05"/>
      <path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>
    </svg>
  )
}
