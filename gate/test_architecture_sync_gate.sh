#!/usr/bin/env bash
# spring-ai-fin architecture-sync gate self-test
# (cycle-7 sec-E1; cycle-8 sec-A2 + sec-A3 extended).
#
# Runs the available platform script(s) on the current working tree
# and asserts:
#   1. exit code is 0 (PASS) or non-zero (FAIL) - either is acceptable;
#      the test verifies STRUCTURED output, not pass/fail outcome.
#   2. a log file is produced.
#   3. the log file is parseable (non-empty JSON-shaped).
#   4. required fields exist: script, version, sha, semantic_pass,
#      evidence_valid_for_delivery, failures.
#   5. (cycle-8 A2) the self-test result is recorded with a SHA in
#      gate/log/local/self-test-<sha>.json and the audit-trail commit
#      copies it to gate/log/self-test-<arch_sha>.json for delivery.
#   6. (cycle-8 A3) two modes: --mode=local-smoke (skip when pwsh
#      missing) or --mode=delivery-required (record per-platform
#      missing_blocker into the JSON). Default is local-smoke.
#
# This harness exists because cycle-6 PowerShell shipped a variable-order
# defect that crashed before producing structured output. Cycle-7 sec-E1
# fix: a self-test like this one would have caught it on first run.
# Cycle-8 sec-A2 fix: passing this harness is now a delivery requirement.

set -euo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mode="local-smoke"
for arg in "$@"; do
  case "$arg" in
    --mode=local-smoke)        mode="local-smoke" ;;
    --mode=delivery-required)  mode="delivery-required" ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--mode=local-smoke|--mode=delivery-required]

local-smoke (default): skip PowerShell tests if pwsh is missing.
delivery-required:     record missing pwsh as missing_blocker; exit non-zero.
EOF
      exit 0
      ;;
  esac
done

failed=0
total=0
windows_state="not_run"

assert_log_structured() {
  local script_name="$1"
  local log_pattern="$2"
  shift 2
  local required_fields=("$@")
  total=$((total + 1))
  local log_file
  log_file=$(ls -t $log_pattern 2>/dev/null | head -1 || true)
  if [[ -z "$log_file" || ! -f "$log_file" ]]; then
    echo "FAIL [$script_name]: no log produced (pattern: $log_pattern)" >&2
    failed=$((failed + 1))
    return
  fi
  if [[ ! -s "$log_file" ]]; then
    echo "FAIL [$script_name]: log file is empty: $log_file" >&2
    failed=$((failed + 1))
    return
  fi
  for field in "${required_fields[@]}"; do
    if ! grep -q "$field" "$log_file"; then
      echo "FAIL [$script_name]: log missing field $field in $log_file" >&2
      failed=$((failed + 1))
      return
    fi
  done
  local first_byte
  first_byte=$(head -c1 "$log_file")
  if [[ "$first_byte" != "{" ]]; then
    echo "FAIL [$script_name]: log does not start with { in $log_file" >&2
    failed=$((failed + 1))
    return
  fi
  echo "OK   [$script_name]: structured log at $log_file"
}

ARCH_SYNC_FIELDS=('"script"' '"version"' '"sha"' '"semantic_pass"' '"evidence_valid_for_delivery"' '"failures"')
SMOKE_FIELDS=('"script"' '"version"' '"sha"' '"outcome"' '"artifact_present"' '"rule_8_evidence"')

# 1. POSIX architecture-sync gate.
echo "==> Running POSIX architecture-sync gate (--local-only to tolerate test-time dirty tree)..."
if bash gate/check_architecture_sync.sh --local-only > /dev/null 2>&1 || true; then
  : # exit code is irrelevant; we test that it produced structured output
fi
sha=$(git rev-parse --short HEAD 2>/dev/null || echo no-git)
assert_log_structured "check_architecture_sync.sh" "gate/log/${sha}-posix.json gate/log/local/${sha}-posix.json" "${ARCH_SYNC_FIELDS[@]}"

# 2. PowerShell architecture-sync gate (cycle-8 A3: parity contract).
if command -v pwsh >/dev/null 2>&1; then
  echo "==> Running PowerShell architecture-sync gate..."
  pwsh -NoProfile -ExecutionPolicy Bypass -File gate/check_architecture_sync.ps1 -LocalOnly > /dev/null 2>&1 || true
  assert_log_structured "check_architecture_sync.ps1" "gate/log/${sha}-windows.json gate/log/local/${sha}-windows.json" "${ARCH_SYNC_FIELDS[@]}"
  windows_state="run"
else
  if [[ "$mode" == "delivery-required" ]]; then
    echo "FAIL [check_architecture_sync.ps1]: pwsh missing under --mode=delivery-required" >&2
    failed=$((failed + 1))
    total=$((total + 1))
    windows_state="missing_blocker"
  else
    echo "SKIP [check_architecture_sync.ps1]: pwsh not available in this environment (local-smoke mode)"
    windows_state="missing_blocker_local_smoke"
  fi
fi

# 3. Operator-shape smoke gate (POSIX) - must fail closed.
echo "==> Running operator-shape smoke gate (POSIX); expecting FAIL_ARTIFACT_MISSING..."
bash gate/run_operator_shape_smoke.sh > /dev/null 2>&1 || true
assert_log_structured "run_operator_shape_smoke.sh" "gate/log/local/operator-shape-${sha}-posix.json" "${SMOKE_FIELDS[@]}"

# 4. Operator-shape smoke gate (PowerShell) if available.
if command -v pwsh >/dev/null 2>&1; then
  echo "==> Running operator-shape smoke gate (PowerShell)..."
  pwsh -NoProfile -ExecutionPolicy Bypass -File gate/run_operator_shape_smoke.ps1 > /dev/null 2>&1 || true
  assert_log_structured "run_operator_shape_smoke.ps1" "gate/log/local/operator-shape-${sha}-windows.json" "${SMOKE_FIELDS[@]}"
else
  echo "SKIP [run_operator_shape_smoke.ps1]: pwsh not available in this environment"
fi

echo ""
echo "Self-test summary: $((total - failed))/$total checks passed."

# Cycle-8 A2: record a structured self-test result for the manifest /
# delivery file. local-only result lives in gate/log/local/; the audit-trail
# commit copies it to gate/log/self-test-<arch_sha>.json for delivery.
result_dir="gate/log/local"
mkdir -p "$result_dir"
result_path="$result_dir/self-test-${sha}.json"
if [[ $failed -gt 0 ]]; then result_outcome="fail"; else result_outcome="pass"; fi
{
  printf '{'
  printf '"script":"test_architecture_sync_gate.sh",'
  printf '"version":"cycle-8-self-test",'
  printf '"sha":"%s",' "$sha"
  printf '"mode":"%s",' "$mode"
  printf '"generated":"%s",' "$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '"total":%d,' "$total"
  printf '"failed":%d,' "$failed"
  printf '"outcome":"%s",' "$result_outcome"
  printf '"windows_state":"%s"' "$windows_state"
  printf '}\n'
} > "$result_path"
echo "Self-test result: $result_path"

if [[ $failed -gt 0 ]]; then
  echo "Self-test FAILED ($failed checks failed)" >&2
  exit 1
fi
echo "Self-test PASSED."
exit 0
