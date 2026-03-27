#!/usr/bin/env bash
# test_brew_install.sh — Tests brew-based app installation
# Test app: jq (lightweight, safe, widely available)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

TEST_APP="jq"
TEST_SUITE="brew_install"

# ── Helpers ──────────────────────────────────────────────────────────────────

pre_clean() {
  if brew list --formula "$TEST_APP" &>/dev/null; then
    log_info "Pre-test: uninstalling existing $TEST_APP"
    brew uninstall "$TEST_APP" &>/dev/null || true
  fi
}

post_clean() {
  log_info "Post-test: removing $TEST_APP"
  brew uninstall "$TEST_APP" &>/dev/null || true
}

# ── Tests ─────────────────────────────────────────────────────────────────────

test_brew_install_success() {
  local name="brew_install_success"
  pre_clean

  log_test "$name" "macinstall installs a valid brew formula"
  macinstall install --method brew "$TEST_APP"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_command_exists "$TEST_APP" "$name"
  post_clean
  pass "$name"
}

test_brew_install_already_installed() {
  local name="brew_install_already_installed"
  pre_clean
  brew install "$TEST_APP" &>/dev/null

  log_test "$name" "macinstall handles already-installed app gracefully"
  local output
  output=$(macinstall install --method brew "$TEST_APP" 2>&1)
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_output_contains "$output" "already installed" "$name"
  post_clean
  pass "$name"
}

test_brew_install_invalid_formula() {
  local name="brew_install_invalid_formula"

  log_test "$name" "macinstall exits non-zero for unknown formula"
  macinstall install --method brew "this-formula-does-not-exist-xyz-999" 2>/dev/null
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  pass "$name"
}

test_brew_install_dry_run() {
  local name="brew_install_dry_run"
  pre_clean

  log_test "$name" "macinstall dry-run does not actually install"
  macinstall install --method brew --dry-run "$TEST_APP"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_command_not_exists_or_was_present "$TEST_APP" "$name"
  pass "$name"
}

test_brew_install_force_reinstall() {
  local name="brew_install_force_reinstall"
  pre_clean
  brew install "$TEST_APP" &>/dev/null

  log_test "$name" "macinstall --force reinstalls an existing app"
  macinstall install --method brew --force "$TEST_APP"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_command_exists "$TEST_APP" "$name"
  post_clean
  pass "$name"
}

# ── Runner ────────────────────────────────────────────────────────────────────

main() {
  suite_start "$TEST_SUITE"

  require_command "brew" "Homebrew must be installed"
  require_command "macinstall" "macinstall CLI must be on PATH"

  test_brew_install_success
  test_brew_install_already_installed
  test_brew_install_invalid_formula
  test_brew_install_dry_run
  test_brew_install_force_reinstall

  suite_end "$TEST_SUITE"
}

main "$@"
