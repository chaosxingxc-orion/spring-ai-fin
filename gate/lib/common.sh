#!/usr/bin/env bash
# gate/lib/common.sh -- shared helpers for the gate.
#
# Provides:
#   - pass_rule / fail_rule (backward-compatible with the monolith API)
#   - log_jsonl (atomic NDJSON line writer used by run_rule.sh)
#   - gate_now_ms (portable millisecond timestamp)
#   - fail_count (global accumulator, same name as the monolith uses)
#
# Authority: docs/governance/rules/rule-67.md ... rule-73.md + token-optimization wave Phase 2.

set -uo pipefail
export LC_ALL=C

# fail_count is the same global the monolith uses. Workers spawn a fresh subshell
# per rule, so each rule's fail_count is local to that subshell -- we use the
# fail_count==0 -> rule passed convention by setting it back to 0 at the top of
# each rule's invocation in run_rule.sh.
: "${fail_count:=0}"

# ---------------------------------------------------------------------------
# Portable millisecond timestamp.
# GNU date supports %N; macOS BSD does not. Fall back to python.
# ---------------------------------------------------------------------------
gate_now_ms() {
  local _ms
  _ms=$(date +%s%3N 2>/dev/null)
  if [[ -z "$_ms" || "$_ms" == *"N"* ]]; then
    # %3N not supported (BSD); fall back to python
    if command -v python3 >/dev/null 2>&1; then
      python3 -c 'import time; print(int(time.time()*1000))'
    elif command -v python >/dev/null 2>&1; then
      python -c 'import time; print(int(time.time()*1000))'
    else
      # Last resort: second-precision
      printf '%d000' "$(date +%s)"
    fi
  else
    printf '%s' "$_ms"
  fi
}

# ---------------------------------------------------------------------------
# Portable ISO8601 timestamp.
# ---------------------------------------------------------------------------
gate_now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || printf '1970-01-01T00:00:00Z'
}

# ---------------------------------------------------------------------------
# pass_rule / fail_rule -- two-arg form is backward-compatible with the
# monolith's `pass_rule "<slug>"`. Optional 3rd arg is the rule_number (used
# only when GATE_LOG_DIR is set -- writes a structured NDJSON line).
# ---------------------------------------------------------------------------
pass_rule() {
  local _slug="$1"
  local _rule_number="${2:-}"
  echo "PASS: $_slug"
  if [[ -n "${GATE_LOG_DIR:-}" && -n "$_rule_number" ]]; then
    log_jsonl "$_rule_number" "$_slug" "PASS" "${GATE_RULE_DURATION_MS:-0}" ""
  fi
}

fail_rule() {
  local _slug="$1"
  local _reason="$2"
  local _rule_number="${3:-}"
  echo "FAIL: $_slug -- $_reason"
  fail_count=$((fail_count + 1))
  if [[ -n "${GATE_LOG_DIR:-}" && -n "$_rule_number" ]]; then
    log_jsonl "$_rule_number" "$_slug" "FAIL" "${GATE_RULE_DURATION_MS:-0}" "$_reason"
  fi
}

# ---------------------------------------------------------------------------
# log_jsonl -- atomic single-line NDJSON write.
# args: rule_number slug status duration_ms reason
# Uses flock if available to serialise writes across parallel workers.
# ---------------------------------------------------------------------------
log_jsonl() {
  local _rule_number="$1"
  local _slug="$2"
  local _status="$3"
  local _duration_ms="$4"
  local _reason="$5"
  local _now_iso
  _now_iso=$(gate_now_iso)

  # JSON-escape the reason (minimal: backslash, double-quote, newline -> space, tab -> space).
  local _reason_escaped
  _reason_escaped=$(printf '%s' "$_reason" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\t/ /g' | tr '\n' ' ' | tr '\r' ' ')

  local _padded_id
  _padded_id=$(printf '%03d' "$_rule_number")
  local _rule_id="${_padded_id}_${_slug}"

  local _reason_json
  if [[ "$_status" == "PASS" ]]; then
    _reason_json="null"
  else
    _reason_json="\"${_reason_escaped}\""
  fi

  local _json
  _json=$(printf '{"rule_id":"%s","rule_number":%d,"rule_slug":"%s","status":"%s","duration_ms":%d,"finished_at":"%s","reason":%s,"worker_pid":%d}' \
    "$_rule_id" "$_rule_number" "$_slug" "$_status" "$_duration_ms" "$_now_iso" "$_reason_json" "$$")

  local _log_file="${GATE_LOG_DIR}/per-rule.ndjson"
  local _lock_file="${GATE_LOG_DIR}/per-rule.ndjson.lock"

  if command -v flock >/dev/null 2>&1; then
    (
      flock -x 200
      printf '%s\n' "$_json" >> "$_log_file"
    ) 200>"$_lock_file"
  else
    # No flock -- atomic single-write append should still be safe for short lines
    # on POSIX (PIPE_BUF >= 512 bytes, our lines are typically <300).
    printf '%s\n' "$_json" >> "$_log_file"
  fi
}
