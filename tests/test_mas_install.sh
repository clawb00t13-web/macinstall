#!/usr/bin/env bash
# test_mas_install.sh — Tests Mac App Store installation via mas-cli
# Test app: Lungo (1263070803) — free, lightweight, no login side effects
#           or Amphetamine (937984704) — both are free menu bar utilities

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

TEST_APP_ID="1263070803"   # Lungo — free, small, menu bar app
TEST_APP_NAME="Lungo"
TEST_SUITE="mas_install"

# ── Helpers ──────────────────────────────────────────────────────────────────

pre_clean() {
  if mas list 2>/dev/null | grep -q "$TEST_APP_ID"; then
    log_info "Pre-test: uninstalling $TEST_APP_NAME"
    mas uninstall "$TEST_APP_ID" &>/dev/null || true
  fi
}

post_clean() {
  log_info "Post-test: removing $TEST_APP_NAME"
  mas uninstall "$TEST_APP_ID" &>/dev/null || true
}

# ── Tests ─────────────────────────────────────────────────────────────────────

test_mas_install_success() {
  local name="mas_install_success"
  pre_clean

  log_test "$name" "macinstall installs a valid MAS app by ID"
  macinstall install --method mas "$TEST_APP_ID"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_app_installed "$TEST_APP_NAME" "$name"
  post_clean
  pass "$name"
}

test_mas_install_by_name() {
  local name="mas_install_by_name"
  pre_clean

  log_test "$name" "macinstall resolves app name to MAS ID and installs"
  macinstall install --method mas --search "$TEST_APP_NAME"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_app_installed "$TEST_APP_NAME" "$name"
  post_clean
  pass "$name"
}

test_mas_install_already_installed() {
  local name="mas_install_already_installed"
  # Install first
  mas install "$TEST_APP_ID" &>/dev/null || true

  log_test "$name" "macinstall handles already-installed MAS app gracefully"
  local output
  output=$(macinstall install --method mas "$TEST_APP_ID" 2>&1)
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_output_contains "$output" "already installed" "$name"
  post_clean
  pass "$name"
}

test_mas_install_invalid_id() {
  local name="mas_install_invalid_id"

  log_test "$name" "macinstall exits non-zero for invalid MAS app ID"
  macinstall install --method mas "9999999999" 2>/dev/null
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  pass "$name"
}

test_mas_requires_signin() {
  local name="mas_signin_check"

  log_test "$name" "macinstall detects when user is not signed in to App Store"
  # Simulate: check that tool produces a clear error when mas account is missing
  local signed_in
  signed_in=$(mas account 2>&1)
  if echo "$signed_in" | grep -q "Not signed in"; then
    local output
    output=$(macinstall install --method mas "$TEST_APP_ID" 2>&1)
    assert_output_contains "$output" "sign in" "$name"
    assert_exit_nonzero $? "$name"
  else
    log_info "Skipping $name — user is signed in to App Store"
    skip "$name" "User is signed in; cannot test unsigned state"
  fi
  pass "$name"
}

test_mas_install_dry_run() {
  local name="mas_install_dry_run"
  pre_clean

  log_test "$name" "macinstall dry-run does not install MAS app"
  macinstall install --method mas --dry-run "$TEST_APP_ID"
  local exit_code=$?

  assert_exit_code 0 $exit_code "$name"
  assert_app_not_installed "$TEST_APP_NAME" "$name"
  pass "$name"
}

# ── Runner ────────────────────────────────────────────────────────────────────

main() {
  suite_start "$TEST_SUITE"

  require_command "mas" "mas-cli must be installed (brew install mas)"
  require_command "macinstall" "macinstall CLI must be on PATH"

  test_mas_requires_signin
  test_mas_install_success
  test_mas_install_by_name
  test_mas_install_already_installed
  test_mas_install_invalid_id
  test_mas_install_dry_run

  suite_end "$TEST_SUITE"
}

main "$@"
