// Minimal YAML parse/serialize for the macinstall profile format:
// version: 1
// apps:
//   - id: xxx
//     enabled: true

export type ProfileState = Record<string, boolean>

export function parseProfileYaml(yaml: string): ProfileState {
  const result: ProfileState = {}
  if (!yaml.trim()) return result

  const lines = yaml.split('\n')
  let inApps = false
  let currentId: string | null = null

  for (const raw of lines) {
    const line = raw.trimEnd()

    if (/^apps:/.test(line)) {
      inApps = true
      continue
    }

    if (!inApps) continue

    // New list item: "  - id: xxx"
    const idMatch = line.match(/^\s+-\s+id:\s*(.+)$/)
    if (idMatch) {
      currentId = idMatch[1].trim()
      result[currentId] = true // default enabled
      continue
    }

    // enabled field: "    enabled: true/false"
    const enabledMatch = line.match(/^\s+enabled:\s*(true|false)$/)
    if (enabledMatch && currentId) {
      result[currentId] = enabledMatch[1] === 'true'
      continue
    }
  }

  return result
}

export function serializeProfileYaml(state: ProfileState): string {
  const enabled = Object.entries(state)
    .filter(([, v]) => v)
    .map(([id]) => id)

  if (enabled.length === 0) {
    return 'version: 1\napps: []\n'
  }

  const appLines = Object.entries(state)
    .map(([id, en]) => `  - id: ${id}\n    enabled: ${en}`)
    .join('\n')

  return `version: 1\napps:\n${appLines}\n`
}
