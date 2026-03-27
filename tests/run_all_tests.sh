#!/usr/bin/env bash
# run_all_tests.sh — MacInstall test pipeline orchestrator
#
# Usage:
#   ./run_all_tests.sh                    # Run all suites
#   ./run_all_tests.sh --suite brew       # Run specific suite
#   ./run_all_tests.sh --dry-run          # List tests without running
#   ./run_all_tests.sh --fast             # Skip slow tests (DMG, retry timing)
#
# Exit codes:
#   0 — all tests passed (or all failures were skips)
#   1 — one or more tests failed
#   2 — setup/prerequisite failure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${MACINSTALL_RESULTS_DIR:-/tmp/macinstall_test_results}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_${TIMESTAMP}.log"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── CLI flags ─────────────────────────────────────────────────────────────────
SUITE_FILTER=""
DRY_RUN=false
FAST_MODE=false

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --suite)   SUITE_FILTER="$2"; shift 2 ;;
      --dry-run) DRY_RUN=true; shift ;;
      --fast)    FAST_MODE=true; shift ;;
      *)         echo "Unknown option: $1"; exit 2 ;;
    esac
  done
}

# ── Suite registry ────────────────────────────────────────────────────────────
# Format: "name:script:slow"
declare -a SUITES=(
  "brew:test_brew_install.sh:false"
  "mas:test_mas_install.sh:false"
  "dmg:test_dmg_install.sh:true"
  "errors:test_error_handling.sh:false"
  "retry:test_retry_logic.sh:true"
)

# ── Setup ─────────────────────────────────────────────────────────────────────

setup() {
  mkdir -p "$RESULTS_DIR"
  echo "MacInstall Test Run — $TIMESTAMP" > "$LOG_FILE"
  echo "macinstall version: $(macinstall --version 2>/dev/null || echo 'unknown')" >> "$LOG_FILE"
  echo "macOS: $(sw_vers -productVersion 2>/dev/null || echo 'unknown')" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"
}

check_prerequisites() {
  local missing=0

  echo -e "${BOLD}Checking prerequisites...${RESET}"

  if ! command -v macinstall &>/dev/null; then
    echo -e "  ${RED}✗${RESET} macinstall — not found on PATH"
    echo "  Install macinstall first before running tests."
    missing=$((missing + 1))
  else
    echo -e "  ${GREEN}✓${RESET} macinstall $(macinstall --version 2>/dev/null || echo '')"
  fi

  if command -v brew &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} Homebrew $(brew --version | head -1)"
  else
    echo -e "  ${YELLOW}⚠${RESET} Homebrew not found — brew suite will skip"
  fi

  if command -v mas &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} mas $(mas version)"
  else
    echo -e "  ${YELLOW}⚠${RESET} mas not found — MAS suite will skip"
  fi

  if command -v python3 &>/dev/null; then
    echo -e "  ${GREEN}✓${RESET} python3 (used for retry mock server)"
  else
    echo -e "  ${YELLOW}⚠${RESET} python3 not found — some retry tests will skip"
  fi

  echo ""

  if [ $missing -gt 0 ]; then
    echo -e "${RED}Fatal: $missing required prerequisite(s) missing.${RESET}"
    exit 2
  fi
}

# ── Runner ────────────────────────────────────────────────────────────────────

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
declare -a SUITE_RESULTS=()

run_suite() {
  local name="$1"
  local script="$2"
  local is_slow="$3"
  local script_path="${SCRIPT_DIR}/${script}"

  if $FAST_MODE && [ "$is_slow" = "true" ]; then
    echo -e "${YELLOW}[SKIP]${RESET} Suite '$name' — skipped in fast mode"
    SUITE_RESULTS+=("SKIP  $name (fast mode)")
    return
  fi

  if [ ! -f "$script_path" ]; then
    echo -e "${YELLOW}[SKIP]${RESET} Suite '$name' — script not found: $script_path"
    SUITE_RESULTS+=("MISS  $name (script not found)")
    return
  fi

  if $DRY_RUN; then
    echo -e "${CYAN}[DRY]${RESET}  Would run suite: $name ($script)"
    SUITE_RESULTS+=("DRY   $name")
    return
  fi

  echo -e "${BOLD}Running suite: $name${RESET}"
  local suite_log="${RESULTS_DIR}/suite_${name}_${TIMESTAMP}.log"

  # Run suite, capture output, show live + save to log
  local exit_code=0
  bash "$script_path" 2>&1 | tee "$suite_log" || exit_code=${PIPESTATUS[0]}

  # Parse results from log
  local pass skip fail
  pass=$(grep -c "✓ PASS" "$suite_log" 2>/dev/null || echo 0)
  fail=$(grep -c "✗ FAIL" "$suite_log" 2>/dev/null || echo 0)
  skip=$(grep -c "⊘ SKIP" "$suite_log" 2>/dev/null || echo 0)

  TOTAL_PASS=$((TOTAL_PASS + pass))
  TOTAL_FAIL=$((TOTAL_FAIL + fail))
  TOTAL_SKIP=$((TOTAL_SKIP + skip))

  if [ "$exit_code" -eq 0 ]; then
    SUITE_RESULTS+=("PASS  $name (${pass}p / ${skip}s / ${fail}f)")
  else
    SUITE_RESULTS+=("FAIL  $name (${pass}p / ${skip}s / ${fail}f)")
  fi

  cat "$suite_log" >> "$LOG_FILE"
}

# ── Summary ───────────────────────────────────────────────────────────────────

print_summary() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}       MacInstall Test Summary         ${RESET}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""

  for result in "${SUITE_RESULTS[@]}"; do
    local status="${result:0:4}"
    local rest="${result:6}"
    case "$status" in
      PASS) echo -e "  ${GREEN}✓${RESET} $rest" ;;
      FAIL) echo -e "  ${RED}✗${RESET} $rest" ;;
      SKIP) echo -e "  ${YELLOW}⊘${RESET} $rest" ;;
      MISS) echo -e "  ${YELLOW}?${RESET} $rest" ;;
      DRY ) echo -e "  ${CYAN}○${RESET} $rest" ;;
    esac
  done

  echo ""
  echo -e "  Total passed:  ${GREEN}$TOTAL_PASS${RESET}"
  echo -e "  Total failed:  ${RED}$TOTAL_FAIL${RESET}"
  echo -e "  Total skipped: ${YELLOW}$TOTAL_SKIP${RESET}"
  echo ""

  if [ $TOTAL_FAIL -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All tests passed.${RESET}"
  else
    echo -e "${RED}${BOLD}$TOTAL_FAIL test(s) failed.${RESET}"
    echo "  Full log: $LOG_FILE"
  fi
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  parse_args "$@"

  echo ""
  echo -e "${BOLD}MacInstall Test Pipeline${RESET}"
  echo -e "Run: $TIMESTAMP"
  echo ""

  check_prerequisites
  $DRY_RUN || setup

  for suite_entry in "${SUITES[@]}"; do
    IFS=':' read -r name script slow <<< "$suite_entry"

    # Apply filter if set
    if [ -n "$SUITE_FILTER" ] && [ "$name" != "$SUITE_FILTER" ]; then
      continue
    fi

    run_suite "$name" "$script" "$slow"
    echo ""
  done

  print_summary

  [ $TOTAL_FAIL -eq 0 ]
}

main "$@"
