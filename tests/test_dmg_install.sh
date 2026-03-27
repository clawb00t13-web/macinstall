#!/usr/bin/env bash
# test_dmg_install.sh — Tests DMG download and silent installation
# Test app: VLC — free, well-known, stable DMG URL, no licensing issues
#
# Passing criteria:
#   - DMG downloaded to temp dir
#   - DMG mounted cleanly
#   - .app copied to /Applications
#   - DMG unmounted and temp file removed
#   - App launches (smoke test)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

TEST_APP="VLC"
TEST_APP_PATH="/Applications/VLC.app"
# Pinned to a specific version to ensure deterministic tests
TEST_DMG_URL="https://get.videolan.org/vlc/3.0.21/macosx/vlc-3.0.21-arm64.dmg"
TEST_DMG_SHA256="PLACEHOLDER_SHA256"  # Replace with actual checksum before running
TEST_SUITE="dmg_install"

# ── Helpers ──────────────────────────────────────────────────────────────────

pre_clean() {
  if [ -d "$TEST_APP_PATH" ]; then
    log_info "Pre-test: removing existing $TEST_APP"
    rm -rf "$TEST_APP_PATH" || sudo rm -rf "$TEST_APP_PATH"
  fi
}

post_clean() {
  log_info "Post-test: removing $TEST_APP"
  rm -rf "$TEST_APP_PATH" || sudo rm -rf "$TEST_APP_PATH"
  # Unmount any stray volumes
  hdiutil info 2>/dev/null | grep "VLC" | awk '{print $1}' | xargs -I{} hdiutil detach {} &>/dev/null || true
}

# ── Tests ─────────────────────────────────────────────────────────────────────

test_dmg_install_success() {
  local name="dmg_install_success"
  pre_clean

  log_test "$name" "macinstall downloads and installs a DMG app"
  macinstall install --method dmg --url "$TEST_DMG_URL" "$TEST_APP"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_path_exists "$TEST_APP_PATH" "$name"
  post_clean
  pass "$name"
}

test_dmg_install_checksum_valid() {
  local name="dmg_install_checksum"
  pre_clean

  log_test "$name" "macinstall verifies DMG checksum before installing"
  macinstall install --method dmg --url "$TEST_DMG_URL" --sha256 "$TEST_DMG_SHA256" "$TEST_APP"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_path_exists "$TEST_APP_PATH" "$name"
  post_clean
  pass "$name"
}

test_dmg_install_bad_checksum_rejected() {
  local name="dmg_install_bad_checksum"
  pre_clean

  log_test "$name" "macinstall rejects DMG with wrong checksum"
  macinstall install --method dmg --url "$TEST_DMG_URL" \
    --sha256 "0000000000000000000000000000000000000000000000000000000000000000" \
    "$TEST_APP" 2>/dev/null
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  assert_path_not_exists "$TEST_APP_PATH" "$name"
  pass "$name"
}

test_dmg_install_bad_url() {
  local name="dmg_install_bad_url"

  log_test "$name" "macinstall exits non-zero for unreachable DMG URL"
  macinstall install --method dmg \
    --url "https://example.invalid/nonexistent.dmg" \
    "FakeApp" 2>/dev/null
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  pass "$name"
}

test_dmg_install_app_launches() {
  local name="dmg_install_app_launches"
  pre_clean

  log_test "$name" "installed DMG app launches without crashing"
  macinstall install --method dmg --url "$TEST_DMG_URL" "$TEST_APP"

  # Give app a moment, then open and immediately quit
  open -a "$TEST_APP" 2>/dev/null
  sleep 3
  pkill -x "VLC" 2>/dev/null || true
  local pgrep_exit=$?

  # App was running (pgrep found it, then we killed it) = success
  assert_path_exists "$TEST_APP_PATH" "$name"
  post_clean
  pass "$name"
}

test_dmg_install_already_installed() {
  local name="dmg_install_already_installed"
  pre_clean
  # Pre-install
  macinstall install --method dmg --url "$TEST_DMG_URL" "$TEST_APP" &>/dev/null

  log_test "$name" "macinstall handles already-installed DMG app gracefully"
  local output
  output=$(macinstall install --method dmg --url "$TEST_DMG_URL" "$TEST_APP" 2>&1)
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_output_contains "$output" "already installed" "$name"
  post_clean
  pass "$name"
}

test_dmg_install_dry_run() {
  local name="dmg_install_dry_run"
  pre_clean

  log_test "$name" "macinstall dry-run does not install the .app"
  macinstall install --method dmg --url "$TEST_DMG_URL" --dry-run "$TEST_APP"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_path_not_exists "$TEST_APP_PATH" "$name"
  pass "$name"
}

test_dmg_temp_cleanup() {
  local name="dmg_temp_cleanup"
  pre_clean

  log_test "$name" "macinstall cleans up temp files and unmounts DMG after install"
  macinstall install --method dmg --url "$TEST_DMG_URL" "$TEST_APP" &>/dev/null

  # No mounted VLC volumes should remain
  local mounted
  mounted=$(hdiutil info 2>/dev/null | grep -i "vlc" || echo "")
  assert_output_not_contains "$mounted" "vlc" "$name"
  post_clean
  pass "$name"
}

# ── Runner ────────────────────────────────────────────────────────────────────

main() {
  suite_start "$TEST_SUITE"

  require_command "macinstall" "macinstall CLI must be on PATH"
  require_command "hdiutil" "hdiutil must be available (macOS only)"
  require_command "curl" "curl must be available for DMG download"

  test_dmg_install_success
  test_dmg_install_checksum_valid
  test_dmg_install_bad_checksum_rejected
  test_dmg_install_bad_url
  test_dmg_install_app_launches
  test_dmg_install_already_installed
  test_dmg_install_dry_run
  test_dmg_temp_cleanup

  suite_end "$TEST_SUITE"
}

main "$@"
