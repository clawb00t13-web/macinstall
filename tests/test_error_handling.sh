#!/usr/bin/env bash
# test_error_handling.sh — Tests error scenarios across all install methods
# Covers: bad input, network failures, permission errors, unsupported OS, conflicts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

TEST_SUITE="error_handling"

# ── Network failure simulation ────────────────────────────────────────────────

test_no_network_brew() {
  local name="error_no_network_brew"

  log_test "$name" "brew install fails gracefully when network is unavailable"
  # Block outbound on lo using pfctl (requires sudo) — skip if not root
  if [ "$EUID" -ne 0 ]; then
    skip "$name" "Requires root to simulate network failure"
    return
  fi

  # Add a blocking pf rule
  echo "block out proto tcp from any to any port 443" | pfctl -f - &>/dev/null
  local output
  output=$(macinstall install --method brew jq 2>&1)
  local exit_code=$?
  pfctl -F all &>/dev/null  # Flush rules

  assert_exit_nonzero $exit_code "$name"
  assert_output_contains "$output" "network" "$name" || \
    assert_output_contains "$output" "connect" "$name"
  pass "$name"
}

# ── Bad input ─────────────────────────────────────────────────────────────────

test_missing_app_name() {
  local name="error_missing_app_name"

  log_test "$name" "macinstall exits with usage error when no app is specified"
  macinstall install --method brew 2>/dev/null
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  pass "$name"
}

test_unknown_method() {
  local name="error_unknown_method"

  log_test "$name" "macinstall exits non-zero for unsupported install method"
  macinstall install --method floppy-disk "SomeApp" 2>/dev/null
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  pass "$name"
}

test_malformed_mas_id() {
  local name="error_malformed_mas_id"

  log_test "$name" "macinstall rejects non-numeric MAS ID"
  local output
  output=$(macinstall install --method mas "not-an-id" 2>&1)
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  assert_output_contains "$output" "invalid" "$name" || \
    assert_output_contains "$output" "id" "$name"
  pass "$name"
}

test_dmg_non_https_url_rejected() {
  local name="error_dmg_non_https"

  log_test "$name" "macinstall rejects http:// DMG URLs (security requirement)"
  local output
  output=$(macinstall install --method dmg --url "http://example.com/app.dmg" "App" 2>&1)
  local exit_code=$?

  assert_exit_nonzero $exit_code "$name"
  assert_output_contains "$output" "https" "$name" || \
    assert_output_contains "$output" "secure" "$name"
  pass "$name"
}

# ── Permission errors ─────────────────────────────────────────────────────────

test_no_write_permission_applications() {
  local name="error_no_write_permission"

  log_test "$name" "macinstall surfaces a clear error when /Applications is not writable"
  # Run as a user without write access to /Applications (simulate by chmod)
  if [ "$EUID" -eq 0 ]; then
    skip "$name" "Running as root — cannot simulate permission denied"
    return
  fi

  # Check if /Applications is already not writable for current user
  if [ ! -w "/Applications" ]; then
    local output
    output=$(macinstall install --method dmg --url "https://example.com/app.dmg" "App" 2>&1)
    assert_output_contains "$output" "permission" "$name" || \
      assert_output_contains "$output" "access" "$name"
    assert_exit_nonzero $? "$name"
  else
    skip "$name" "Current user has write access to /Applications"
  fi
  pass "$name"
}

# ── Conflict detection ────────────────────────────────────────────────────────

test_method_conflict_detection() {
  local name="error_method_conflict"

  log_test "$name" "macinstall detects when same app is managed by multiple methods"
  # Install jq via brew, then try to install again via a hypothetical dmg path
  # macinstall should warn about method conflict
  brew install jq &>/dev/null || true
  local output
  output=$(macinstall install --method dmg \
    --url "https://example.com/jq.dmg" "jq" 2>&1)
  local exit_code=$?

  # Should either warn and succeed, or exit with explicit conflict message
  assert_output_contains "$output" "conflict" "$name" || \
    assert_output_contains "$output" "already managed" "$name" || \
    assert_exit_code 0 $exit_code "$name"
  brew uninstall jq &>/dev/null || true
  pass "$name"
}

# ── Missing dependencies ──────────────────────────────────────────────────────

test_mas_not_installed_error() {
  local name="error_mas_not_installed"

  log_test "$name" "macinstall gives actionable error when mas-cli is not installed"
  if command -v mas &>/dev/null; then
    skip "$name" "mas is installed — cannot test missing-dependency path"
    return
  fi

  local output
  output=$(macinstall install --method mas "1263070803" 2>&1)
  assert_exit_nonzero $? "$name"
  assert_output_contains "$output" "mas" "$name"
  pass "$name"
}

test_homebrew_not_installed_error() {
  local name="error_homebrew_not_installed"

  log_test "$name" "macinstall gives actionable error when Homebrew is not installed"
  if command -v brew &>/dev/null; then
    skip "$name" "Homebrew is installed — cannot test missing-dependency path"
    return
  fi

  local output
  output=$(macinstall install --method brew "jq" 2>&1)
  assert_exit_nonzero $? "$name"
  assert_output_contains "$output" "brew" "$name" || \
    assert_output_contains "$output" "homebrew" "$name"
  pass "$name"
}

# ── Output format ─────────────────────────────────────────────────────────────

test_error_output_to_stderr() {
  local name="error_output_to_stderr"

  log_test "$name" "macinstall writes errors to stderr, not stdout"
  local stdout_out stderr_out
  stdout_out=$(macinstall install --method brew "nonexistent-pkg-xyz" 2>/dev/null)
  stderr_out=$(macinstall install --method brew "nonexistent-pkg-xyz" 2>&1 >/dev/null)

  # stdout should be empty or minimal; stderr should contain error info
  if [ -n "$stdout_out" ] && [ -z "$stderr_out" ]; then
    fail "$name" "Error was written to stdout instead of stderr"
  fi
  pass "$name"
}

# ── Runner ────────────────────────────────────────────────────────────────────

main() {
  suite_start "$TEST_SUITE"

  require_command "macinstall" "macinstall CLI must be on PATH"

  test_missing_app_name
  test_unknown_method
  test_malformed_mas_id
  test_dmg_non_https_url_rejected
  test_no_write_permission_applications
  test_method_conflict_detection
  test_mas_not_installed_error
  test_homebrew_not_installed_error
  test_error_output_to_stderr
  test_no_network_brew  # Last — requires sudo

  suite_end "$TEST_SUITE"
}

main "$@"
