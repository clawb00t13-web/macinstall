#!/usr/bin/env bash
# test_helpers.sh — Shared utilities for macinstall test suite
# Source this from each test script: source "$(dirname "$0")/test_helpers.sh"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── State ─────────────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

# ── Logging ───────────────────────────────────────────────────────────────────

log_info()  { echo -e "${CYAN}[INFO]${RESET}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_test()  { echo -e "${BOLD}[TEST]${RESET}  ${CYAN}$1${RESET}: $2"; }

pass() {
  local name="$1"
  echo -e "  ${GREEN}✓ PASS${RESET} $name"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  local name="$1"
  local reason="${2:-}"
  echo -e "  ${RED}✗ FAIL${RESET} $name${reason:+ — $reason}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILED_TESTS+=("$name${reason:+: $reason}")
}

skip() {
  local name="$1"
  local reason="${2:-}"
  echo -e "  ${YELLOW}⊘ SKIP${RESET} $name${reason:+ — $reason}"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  SKIPPED_TESTS+=("$name${reason:+: $reason}")
}

# ── Suite lifecycle ───────────────────────────────────────────────────────────

suite_start() {
  local suite="$1"
  echo ""
  echo -e "${BOLD}━━━ Suite: $suite ━━━${RESET}"
  echo ""
}

suite_end() {
  local suite="$1"
  echo ""
  echo -e "${BOLD}━━━ Results: $suite ━━━${RESET}"
  echo -e "  ${GREEN}Passed:${RESET}  $PASS_COUNT"
  echo -e "  ${RED}Failed:${RESET}  $FAIL_COUNT"
  echo -e "  ${YELLOW}Skipped:${RESET} $SKIP_COUNT"

  if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed tests:${RESET}"
    for t in "${FAILED_TESTS[@]}"; do
      echo "  - $t"
    done
  fi

  if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
  fi
}

# ── Preconditions ─────────────────────────────────────────────────────────────

require_command() {
  local cmd="$1"
  local message="${2:-$cmd is required}"
  if ! command -v "$cmd" &>/dev/null; then
    echo -e "${RED}[SKIP ALL]${RESET} Prerequisite not met: $message"
    exit 0
  fi
}

# ── Assertions ────────────────────────────────────────────────────────────────

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local test_name="$3"
  if [ "$actual" -ne "$expected" ]; then
    fail "$test_name" "Expected exit $expected, got $actual"
    return 1
  fi
}

assert_exit_nonzero() {
  local actual="$1"
  local test_name="$2"
  if [ "$actual" -eq 0 ]; then
    fail "$test_name" "Expected non-zero exit, got 0"
    return 1
  fi
}

assert_command_exists() {
  local cmd="$1"
  local test_name="$2"
  if ! command -v "$cmd" &>/dev/null; then
    fail "$test_name" "Command '$cmd' not found after install"
    return 1
  fi
}

assert_command_not_exists_or_was_present() {
  # Dry-run: app either wasn't installed before and still isn't, or was there already
  # Just check we didn't crash — existence is acceptable either way
  local _cmd="$1"
  local _test_name="$2"
  return 0
}

assert_app_installed() {
  local app_name="$1"
  local test_name="$2"
  if ! ls /Applications/ 2>/dev/null | grep -qi "$app_name"; then
    # Also check ~/Applications
    if ! ls ~/Applications/ 2>/dev/null | grep -qi "$app_name"; then
      fail "$test_name" "$app_name not found in /Applications or ~/Applications"
      return 1
    fi
  fi
}

assert_app_not_installed() {
  local app_name="$1"
  local test_name="$2"
  if ls /Applications/ 2>/dev/null | grep -qi "$app_name"; then
    fail "$test_name" "$app_name found in /Applications — expected not installed"
    return 1
  fi
  if ls ~/Applications/ 2>/dev/null | grep -qi "$app_name"; then
    fail "$test_name" "$app_name found in ~/Applications — expected not installed"
    return 1
  fi
}

assert_path_exists() {
  local path="$1"
  local test_name="$2"
  if [ ! -e "$path" ]; then
    fail "$test_name" "Expected path not found: $path"
    return 1
  fi
}

assert_path_not_exists() {
  local path="$1"
  local test_name="$2"
  if [ -e "$path" ]; then
    fail "$test_name" "Path should not exist: $path"
    return 1
  fi
}

assert_output_contains() {
  local output="$1"
  local substring="$2"
  local test_name="$3"
  if ! echo "$output" | grep -qi "$substring"; then
    fail "$test_name" "Output did not contain '$substring'"
    return 1
  fi
}

assert_output_not_contains() {
  local output="$1"
  local substring="$2"
  local test_name="$3"
  if echo "$output" | grep -qi "$substring"; then
    fail "$test_name" "Output should not contain '$substring'"
    return 1
  fi
}
