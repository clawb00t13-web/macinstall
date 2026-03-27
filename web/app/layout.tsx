import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'MacInstall',
  description: 'Your Mac setup, everywhere.',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className="bg-[#0a0a0a] text-[#f5f5f5] min-h-screen">
        {children}
      </body>
    </html>
  )
}
