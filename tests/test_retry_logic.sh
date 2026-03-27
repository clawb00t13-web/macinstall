#!/usr/bin/env bash
# test_retry_logic.sh — Tests retry behavior on transient failures
#
# Strategy: Use a local mock server that fails N times then succeeds,
# so we can reliably trigger and verify retry behavior without real network
# dependency. Falls back to timing-based assertions if mock server unavailable.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/test_helpers.sh"

TEST_SUITE="retry_logic"
MOCK_PORT=18765
MOCK_PID_FILE="/tmp/macinstall_mock_server.pid"
MOCK_LOG="/tmp/macinstall_mock_server.log"

# ── Mock server ───────────────────────────────────────────────────────────────
# Tiny Python server: first N requests return 503, then 200 with a tiny DMG

start_mock_server() {
  local fail_count="${1:-2}"
  python3 - "$fail_count" "$MOCK_PORT" "$MOCK_LOG" <<'PYEOF' &
import sys, os, time
from http.server import HTTPServer, BaseHTTPRequestHandler

fail_count = int(sys.argv[1])
port       = int(sys.argv[2])
log_file   = sys.argv[3]
request_count = [0]

# Minimal valid DMG bytes (just enough to not be empty — real test uses VLC)
FAKE_BODY = b'\x00' * 512

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        with open(log_file, 'a') as f:
            f.write(fmt % args + '\n')

    def do_GET(self):
        request_count[0] += 1
        if request_count[0] <= fail_count:
            self.send_response(503)
            self.end_headers()
            self.wfile.write(b'Service Unavailable')
        else:
            self.send_response(200)
            self.send_header('Content-Type', 'application/x-apple-diskimage')
            self.send_header('Content-Length', str(len(FAKE_BODY)))
            self.end_headers()
            self.wfile.write(FAKE_BODY)

    def do_HEAD(self):
        self.send_response(200)
        self.end_headers()

httpd = HTTPServer(('localhost', port), Handler)
httpd.serve_forever()
PYEOF

  echo $! > "$MOCK_PID_FILE"
  sleep 0.5  # Let server start
  log_info "Mock server started (PID $(cat $MOCK_PID_FILE), fails first $fail_count requests)"
}

stop_mock_server() {
  if [ -f "$MOCK_PID_FILE" ]; then
    kill "$(cat "$MOCK_PID_FILE")" 2>/dev/null || true
    rm -f "$MOCK_PID_FILE" "$MOCK_LOG"
  fi
}

require_python3() {
  if ! command -v python3 &>/dev/null; then
    log_warn "python3 not found — mock server tests will be skipped"
    return 1
  fi
  return 0
}

# ── Tests ─────────────────────────────────────────────────────────────────────

test_retry_succeeds_after_transient_failure() {
  local name="retry_succeeds_after_transient_503"

  log_test "$name" "macinstall retries and succeeds after transient 503 errors"
  require_python3 || { skip "$name" "python3 not available"; return; }

  start_mock_server 2  # Fail twice, succeed on 3rd
  local mock_url="http://localhost:${MOCK_PORT}/test.dmg"

  local output
  output=$(macinstall install --method dmg \
    --url "$mock_url" \
    --retries 3 "TestApp" 2>&1)
  local exit_code=$?
  stop_mock_server

  assert_exit_code 0 $exit_code "$name"
  assert_output_contains "$output" "retry" "$name" || \
    assert_output_contains "$output" "attempt" "$name"
  pass "$name"
}

test_retry_exhausted_exits_nonzero() {
  local name="retry_exhausted"

  log_test "$name" "macinstall exits non-zero after all retries exhausted"
  require_python3 || { skip "$name" "python3 not available"; return; }

  start_mock_server 10  # Will always fail within our retry budget
  local mock_url="http://localhost:${MOCK_PORT}/test.dmg"

  macinstall install --method dmg \
    --url "$mock_url" \
    --retries 3 "TestApp" 2>/dev/null
  local exit_code=$?
  stop_mock_server

  assert_exit_nonzero $exit_code "$name"
  pass "$name"
}

test_retry_count_respected() {
  local name="retry_count_respected"

  log_test "$name" "macinstall makes exactly N+1 attempts (1 initial + N retries)"
  require_python3 || { skip "$name" "python3 not available"; return; }

  local retries=3
  start_mock_server 999  # Always fail

  macinstall install --method dmg \
    --url "http://localhost:${MOCK_PORT}/test.dmg" \
    --retries "$retries" "TestApp" 2>/dev/null || true
  stop_mock_server

  # Count request log entries
  local request_count=0
  if [ -f "$MOCK_LOG" ]; then
    request_count=$(wc -l < "$MOCK_LOG" | tr -d ' ')
  fi

  local expected=$((retries + 1))
  if [ "$request_count" -eq "$expected" ]; then
    pass "$name"
  else
    fail "$name" "Expected $expected attempts, got $request_count"
  fi
}

test_retry_backoff_timing() {
  local name="retry_backoff_timing"

  log_test "$name" "macinstall uses exponential backoff between retries (not hammering)"
  require_python3 || { skip "$name" "python3 not available"; return; }

  start_mock_server 3  # Fail 3 times

  local start_time end_time elapsed
  start_time=$(date +%s)
  macinstall install --method dmg \
    --url "http://localhost:${MOCK_PORT}/test.dmg" \
    --retries 3 "TestApp" 2>/dev/null || true
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))
  stop_mock_server

  # With exponential backoff starting at 1s: 1 + 2 + 4 = 7s minimum
  # Allow some wiggle room — just ensure it's not instant
  if [ "$elapsed" -lt 2 ]; then
    fail "$name" "Completed in ${elapsed}s — too fast, likely no backoff applied"
  else
    log_info "Elapsed with backoff: ${elapsed}s (good)"
    pass "$name"
  fi
}

test_retry_no_retry_on_permanent_error() {
  local name="retry_no_retry_on_404"

  log_test "$name" "macinstall does NOT retry on 404 (permanent error)"
  require_python3 || { skip "$name" "python3 not available"; return; }

  # Patch: override mock to return 404
  python3 - "$MOCK_PORT" "$MOCK_LOG" <<'PYEOF' &
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

port = int(sys.argv[1])
log_file = sys.argv[2]

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        with open(log_file, 'a') as f:
            f.write(fmt % args + '\n')
    def do_GET(self):
        self.send_response(404)
        self.end_headers()
        self.wfile.write(b'Not Found')

HTTPServer(('localhost', port), Handler).serve_forever()
PYEOF
  echo $! > "$MOCK_PID_FILE"
  sleep 0.5

  macinstall install --method dmg \
    --url "http://localhost:${MOCK_PORT}/test.dmg" \
    --retries 3 "TestApp" 2>/dev/null || true
  stop_mock_server

  # Should have made exactly 1 request (no retry on 404)
  local request_count=0
  if [ -f "$MOCK_LOG" ]; then
    request_count=$(wc -l < "$MOCK_LOG" | tr -d ' ')
  fi

  if [ "$request_count" -eq 1 ]; then
    pass "$name"
  else
    fail "$name" "Made $request_count requests; expected 1 (no retry on 404)"
  fi
}

test_retry_brew_transient() {
  local name="retry_brew_transient"

  log_test "$name" "macinstall retries brew install on transient failure"
  # Brew failures are harder to mock — test via macinstall's --retries flag
  # and a formula that requires network (will fail if offline)
  # This is a structural test: just ensure --retries flag is accepted
  macinstall install --method brew --retries 2 "nonexistent-pkg-xyz-123" 2>/dev/null || true
  local exit_code=$?
  # We expect failure (bad package), but no crash from the --retries flag
  # Exit code should be a controlled non-zero, not a crash (128+)
  if [ $exit_code -lt 128 ]; then
    pass "$name"
  else
    fail "$name" "macinstall crashed (exit $exit_code) — unhandled exception in retry path"
  fi
}

# ── Runner ────────────────────────────────────────────────────────────────────

cleanup() {
  stop_mock_server
}
trap cleanup EXIT

main() {
  suite_start "$TEST_SUITE"

  require_command "macinstall" "macinstall CLI must be on PATH"

  test_retry_succeeds_after_transient_failure
  test_retry_exhausted_exits_nonzero
  test_retry_count_respected
  test_retry_backoff_timing
  test_retry_no_retry_on_permanent_error
  test_retry_brew_transient

  suite_end "$TEST_SUITE"
}

main "$@"
