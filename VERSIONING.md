# MacInstall Versioning Strategy

## Semver

MacInstall follows [Semantic Versioning 2.0.0](https://semver.org): `MAJOR.MINOR.PATCH`

| Bump | When |
|------|------|
| **MAJOR** | Breaking CLI flags, changed config schema, removed install methods |
| **MINOR** | New install method, new CLI flag, new sync feature (backwards-compatible) |
| **PATCH** | Bug fixes, retry logic tweaks, error message improvements |

Pre-release: `1.0.0-beta.1`, `1.0.0-rc.1`
Build metadata (not for release): `1.0.0+20260327`

**Current version lives in:** `VERSION` file at repo root (single source of truth).
All components (CLI, native app, backend) read from this file at build time.

---

## Changelog Format

File: `CHANGELOG.md` at repo root.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) — newest version at top.

```markdown
# Changelog

## [Unreleased]

### Added
- ...

### Fixed
- ...

## [1.2.0] — 2026-03-27

### Added
- DMG install method with SHA-256 checksum verification
- `--dry-run` flag across all install methods

### Changed
- Retry backoff now exponential (was linear)

### Fixed
- brew install incorrectly reported "already installed" for casks (#42)

### Security
- Reject http:// DMG URLs; require https (#38)

## [1.1.0] — 2026-03-10
...
```

### Section order: Added → Changed → Deprecated → Removed → Fixed → Security

---

## Release Process

1. Merge all changes to `main`
2. Update `CHANGELOG.md`: move `[Unreleased]` items under `[X.Y.Z] — YYYY-MM-DD`
3. Bump `VERSION` file
4. Commit: `git commit -m "chore: release vX.Y.Z"`
5. Tag: `git tag -s vX.Y.Z -m "vX.Y.Z"`
6. Push tag — CI builds and publishes release artifacts

---

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, always releasable |
| `dev` | Integration branch for features |
| `feat/...` | Feature branches, merge to `dev` |
| `fix/...` | Bug fix branches, merge to `main` or `dev` |
| `release/X.Y.Z` | Release prep — only changelog + version bumps |
