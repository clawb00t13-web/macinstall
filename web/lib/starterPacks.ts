export type StarterPack = {
  id: string
  name: string
  description: string
  tagline: string
  icon: string
  appIds: string[]
}

export const STARTER_PACKS: StarterPack[] = [
  {
    id: 'developer-setup',
    name: 'Developer Setup',
    tagline: 'Everything a software engineer needs to ship on day one',
    description: 'The essential toolkit for modern software development. Includes the most popular editor, terminal, version control, containerization, API testing, and database tools.',
    icon: '💻',
    appIds: ['visual-studio-code', 'iterm2', 'docker', 'tableplus', 'postman', 'github-desktop', 'rectangle', '1password', 'raycast', 'warp', 'cursor'],
  },
  {
    id: 'designer-setup',
    name: 'Designer Setup',
    tagline: 'A complete creative environment for UI/UX and visual designers',
    description: 'Curated tools for product designers and visual artists. Covers UI design, vector illustration, photo editing, font management, and design handoff.',
    icon: '🎨',
    appIds: ['figma', 'sketch', 'cleanshot-x', 'imageoptim', 'rectangle', '1password', 'raycast', 'canva', 'obsidian'],
  },
  {
    id: 'content-creator-setup',
    name: 'Content Creator',
    tagline: 'Record, edit, and publish content like a pro',
    description: 'Built for YouTubers, streamers, podcasters, and social media creators. Covers screen recording, video editing, audio production, and live streaming.',
    icon: '🎬',
    appIds: ['obs', 'loom', 'davinci-resolve', 'handbrake', 'iina', 'notion', 'canva', 'rectangle', '1password'],
  },
  {
    id: 'data-science-setup',
    name: 'Data Science',
    tagline: 'From raw data to insight without the environment headaches',
    description: "A batteries-included setup for data scientists and ML engineers. Includes Python, R, notebooks, statistical tools, database clients, and editors.",
    icon: '📊',
    appIds: ['visual-studio-code', 'docker', 'tableplus', 'obsidian', 'rectangle', '1password', 'raycast'],
  },
]
