# MacInstall Integration Checklist

_Last updated: 2026-03-27_

Verify that CLI, native app, and sync backend stay in sync end-to-end.
Run this checklist before any release or major merge.

---

## 1. CLI ↔ Native App

| # | Check | How to Verify | Status |
|---|-------|--------------|--------|
| 1.1 | CLI `macinstall install` triggers a native progress notification | Run `macinstall install --method brew jq`; confirm OS notification appears | ☐ |
| 1.2 | Native app reflects install status after CLI completes | Open native app; installed app appears in "Installed" list | ☐ |
| 1.3 | CLI `--quiet` flag suppresses native notifications | Run with `--quiet`; no notification fires | ☐ |
| 1.4 | Native app can trigger installs that appear in CLI history | Trigger install via app UI; `macinstall history` shows the entry | ☐ |
| 1.5 | CLI and native app share the same app catalog version | `macinstall catalog --version` == catalog version shown in native app footer | ☐ |
| 1.6 | Native app gracefully handles CLI being absent from PATH | Remove CLI from PATH; app shows actionable error, not crash | ☐ |
| 1.7 | Native app uses same install methods (brew/mas/dmg) as CLI | Trigger each method from native app; confirm same behavior as CLI | ☐ |

---

## 2. CLI ↔ Sync Backend

| # | Check | How to Verify | Status |
|---|-------|--------------|--------|
| 2.1 | Install events are pushed to sync backend after completion | Run an install; check backend event log for the entry | ☐ |
| 2.2 | `macinstall sync` pulls latest app list from backend | Modify app list in backend; run `macinstall sync`; local list updates | ☐ |
| 2.3 | `macinstall sync --dry-run` shows diff without applying | Run; confirm no local changes made | ☐ |
| 2.4 | Auth token is read from `~/.config/macinstall/auth.json` | Confirm CLI reads token from expected path, not hardcoded | ☐ |
| 2.5 | Backend is not required for offline installs | Disable network; `macinstall install --method brew jq` succeeds | ☐ |
| 2.6 | Failed sync does not block local install | Disconnect backend; install still works, error surfaced non-fatally | ☐ |
| 2.7 | Sync conflict (local vs remote) surfaces a clear resolution prompt | Create diverged state; run sync; conflict resolution UI appears | ☐ |

---

## 3. Native App ↔ Sync Backend

| # | Check | How to Verify | Status |
|---|-------|--------------|--------|
| 3.1 | Native app auto-syncs on launch | Launch app with stale local state; verify sync triggers | ☐ |
| 3.2 | Native app shows sync status indicator | Check status bar/menu for sync state icon | ☐ |
| 3.3 | Native app handles backend 401 gracefully | Revoke token; confirm app shows re-auth prompt, not crash | ☐ |
| 3.4 | Native app handles backend 503 gracefully | Take backend offline; confirm app shows "offline" state | ☐ |
| 3.5 | Native app respects backend-side feature flags | Toggle a backend feature flag; confirm native app behavior changes | ☐ |

---

## 4. Data Consistency

| # | Check | How to Verify | Status |
|---|-------|--------------|--------|
| 4.1 | Install state consistent across CLI, native app, and backend | Install via CLI; verify all three show the app as installed | ☐ |
| 4.2 | Uninstall via CLI removes from native app list and backend | Uninstall via CLI; native app and backend update within 30s | ☐ |
| 4.3 | App catalog schema version matches across all components | `macinstall catalog --version`; native app; backend `/catalog/version` endpoint | ☐ |
| 4.4 | No duplicate entries after multiple sync events | Run sync 3×; verify no duplicate entries in any component | ☐ |

---

## 5. Error State Consistency

| # | Check | How to Verify | Status |
|---|-------|--------------|--------|
| 5.1 | Failed install is recorded consistently (CLI + native app + backend) | Trigger a known-failing install; verify failure logged in all 3 places | ☐ |
| 5.2 | Retry is surfaced in native app when CLI retry occurs | Trigger a retry scenario; native app shows retry count | ☐ |
| 5.3 | Error messages are the same across CLI output and native app | Compare CLI error text with native app error text for same failure | ☐ |

---

## Sign-off

| Component | Reviewer | Date | Notes |
|-----------|---------|------|-------|
| CLI | | | |
| Native App | | | |
| Sync Backend | | | |
| Integration | | | |
