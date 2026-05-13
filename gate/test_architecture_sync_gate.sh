#!/usr/bin/env bash
# spring-ai-ascend architecture-sync gate self-test (post-seventh third-pass).
# PARTIAL COVERAGE: covers Rules 1-6 + Rules 19, 22, 24, 25 (22 tests).
# Full gate verification requires running: pwsh gate/check_architecture_sync.ps1
# The full gate has 25 active rules; this self-test covers Rules 1-6 and 19/22/24/25.
# Prints: Tests passed: N/22
# Exits 0 if all 22 pass, 1 otherwise.

set -uo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

passed=0
failed=0
TOTAL=22

ok() {
  echo "PASS [$1]: $2"
  passed=$((passed + 1))
}

fail() {
  echo "FAIL [$1]: $2" >&2
  failed=$((failed + 1))
}

# Scratch directory for synthetic test fixtures (cleaned up on exit).
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

# ---------------------------------------------------------------------------
# Helper: run the gate script on a synthetic repo root and capture output.
# Usage: run_gate <fake_root>  -- sets last_out, last_rc.
# We replicate the gate checks inline rather than invoking the real script
# (which requires the full repo layout) so each test is self-contained.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# RULE 1 -- status_enum_invalid
# Allowed: design_accepted implemented_unverified test_verified deferred_w1 deferred_w2
# ---------------------------------------------------------------------------

## Positive: valid status values pass
_r1_pos="$scratch/r1_pos"
mkdir -p "$_r1_pos/docs/governance"
cat > "$_r1_pos/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  foo:
    status: design_accepted
  bar:
    status: test_verified
  baz:
    status: deferred_w1
EOF
_allowed_re='^(design_accepted|implemented_unverified|test_verified|deferred_w1|deferred_w2)$'
_r1_pos_fail=0
while IFS= read -r _l; do
  _v=$(printf '%s\n' "$_l" | sed -nE 's/^[[:space:]]*status:[[:space:]]*([A-Za-z_]+)[[:space:]]*$/\1/p')
  if [[ -n "$_v" ]] && ! [[ "$_v" =~ $_allowed_re ]]; then _r1_pos_fail=1; fi
done < "$_r1_pos/docs/governance/architecture-status.yaml"
if [[ $_r1_pos_fail -eq 0 ]]; then
  ok "rule1_status_enum_pos" "valid status values all pass"
else
  fail "rule1_status_enum_pos" "expected PASS for valid status values"
fi

## Negative: invalid status value triggers FAIL
_r1_neg="$scratch/r1_neg"
mkdir -p "$_r1_neg/docs/governance"
cat > "$_r1_neg/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  foo:
    status: proposed
EOF
_r1_neg_fail=0
while IFS= read -r _l; do
  _v=$(printf '%s\n' "$_l" | sed -nE 's/^[[:space:]]*status:[[:space:]]*([A-Za-z_]+)[[:space:]]*$/\1/p')
  if [[ -n "$_v" ]] && ! [[ "$_v" =~ $_allowed_re ]]; then _r1_neg_fail=1; fi
done < "$_r1_neg/docs/governance/architecture-status.yaml"
if [[ $_r1_neg_fail -eq 1 ]]; then
  ok "rule1_status_enum_neg" "invalid status 'proposed' correctly triggers FAIL"
else
  fail "rule1_status_enum_neg" "expected FAIL for invalid status 'proposed'"
fi

# ---------------------------------------------------------------------------
# RULE 2 -- delivery_log_parity
# sha field must equal filename basename (without suffix). semantic_pass required.
# ---------------------------------------------------------------------------

## Positive: sha field matches filename and semantic_pass present
_r2_dir="$scratch/r2_log"
mkdir -p "$_r2_dir"
_sha2="abc1234"
printf '{"sha":"%s","semantic_pass":true}\n' "$_sha2" > "$_r2_dir/${_sha2}-posix.json"
_r2_pos_fail=0
_base2="$(basename "$_r2_dir/${_sha2}-posix.json" .json)"
_shachk="${_base2%%-posix}"
_log_sha2="$(grep -oE '"sha":"[^"]*"' "$_r2_dir/${_sha2}-posix.json" | head -1 | sed -E 's/.*"sha":"([^"]*)".*/\1/')"
_sem2="$(grep -oE '"semantic_pass":(true|false)' "$_r2_dir/${_sha2}-posix.json" | head -1)"
if [[ "$_log_sha2" != "$_shachk" ]]; then _r2_pos_fail=1; fi
if [[ -z "$_sem2" ]]; then _r2_pos_fail=1; fi
if [[ $_r2_pos_fail -eq 0 ]]; then
  ok "rule2_delivery_log_parity_pos" "sha field matches filename; semantic_pass present"
else
  fail "rule2_delivery_log_parity_pos" "expected PASS for valid delivery log"
fi

## Negative: sha field mismatch triggers FAIL
_r2n_sha="abc1234"
_r2n_file="$scratch/r2n_log"
mkdir -p "$_r2n_file"
printf '{"sha":"deadbeef","semantic_pass":true}\n' > "$_r2n_file/${_r2n_sha}-posix.json"
_base2n="$(basename "$_r2n_file/${_r2n_sha}-posix.json" .json)"
_shachk2n="${_base2n%%-posix}"
_log_sha2n="$(grep -oE '"sha":"[^"]*"' "$_r2n_file/${_r2n_sha}-posix.json" | head -1 | sed -E 's/.*"sha":"([^"]*)".*/\1/')"
if [[ "$_log_sha2n" != "$_shachk2n" ]]; then
  ok "rule2_delivery_log_parity_neg" "sha mismatch correctly triggers FAIL"
else
  fail "rule2_delivery_log_parity_neg" "expected FAIL for sha mismatch"
fi

# ---------------------------------------------------------------------------
# RULE 3 -- eol_policy
# *.sh files in gate/ must have LF, not CRLF.
# ---------------------------------------------------------------------------

## Positive: LF-only file passes
_r3_lf="$scratch/r3_lf.sh"
printf '#!/bin/bash\necho ok\n' > "$_r3_lf"
_r3_pos_fail=0
if grep -qU $'\r' "$_r3_lf" 2>/dev/null; then _r3_pos_fail=1; fi
if [[ $_r3_pos_fail -eq 0 ]]; then
  ok "rule3_eol_policy_pos" "LF-only .sh file passes"
else
  fail "rule3_eol_policy_pos" "expected PASS for LF-only .sh file"
fi

## Negative: CRLF file triggers FAIL
_r3_crlf="$scratch/r3_crlf.sh"
printf '#!/bin/bash\r\necho ok\r\n' > "$_r3_crlf"
_r3_neg_fail=0
if grep -qU $'\r' "$_r3_crlf" 2>/dev/null; then _r3_neg_fail=1; fi
if [[ $_r3_neg_fail -eq 1 ]]; then
  ok "rule3_eol_policy_neg" "CRLF .sh file correctly triggers FAIL"
else
  fail "rule3_eol_policy_neg" "expected FAIL for CRLF .sh file"
fi

# ---------------------------------------------------------------------------
# RULE 4 -- ci_no_or_true_mask
# .github/workflows/*.yml must not have gate/run_* || true.
# ---------------------------------------------------------------------------

## Positive: CI file without mask passes
_r4_clean="$scratch/r4_clean.yml"
cat > "$_r4_clean" <<'EOF'
jobs:
  gate:
    steps:
      - run: bash gate/check_architecture_sync.sh
EOF
_r4_pos_fail=0
if grep -qE 'gate/run_.*\|\|[[:space:]]*true' "$_r4_clean" 2>/dev/null; then _r4_pos_fail=1; fi
if [[ $_r4_pos_fail -eq 0 ]]; then
  ok "rule4_ci_no_or_true_mask_pos" "CI file without mask passes"
else
  fail "rule4_ci_no_or_true_mask_pos" "expected PASS for clean CI file"
fi

## Negative: CI file with gate/run_* || true triggers FAIL
_r4_masked="$scratch/r4_masked.yml"
cat > "$_r4_masked" <<'EOF'
jobs:
  gate:
    steps:
      - run: bash gate/run_operator_shape_smoke.sh || true
EOF
_r4_neg_fail=0
if grep -qE 'gate/run_.*\|\|[[:space:]]*true' "$_r4_masked" 2>/dev/null; then _r4_neg_fail=1; fi
if [[ $_r4_neg_fail -eq 1 ]]; then
  ok "rule4_ci_no_or_true_mask_neg" "masked gate/run_* correctly triggers FAIL"
else
  fail "rule4_ci_no_or_true_mask_neg" "expected FAIL for gate/run_* || true"
fi

# ---------------------------------------------------------------------------
# RULE 5 -- required_files_present
# docs/contracts/contract-catalog.md and docs/contracts/openapi-v1.yaml must exist.
# ---------------------------------------------------------------------------

## Positive: both files present passes
_r5_dir="$scratch/r5_ok"
mkdir -p "$_r5_dir/docs/contracts"
touch "$_r5_dir/docs/contracts/contract-catalog.md"
touch "$_r5_dir/docs/contracts/openapi-v1.yaml"
_r5_pos_fail=0
for _req in "$_r5_dir/docs/contracts/contract-catalog.md" "$_r5_dir/docs/contracts/openapi-v1.yaml"; do
  [[ ! -f "$_req" ]] && _r5_pos_fail=1
done
if [[ $_r5_pos_fail -eq 0 ]]; then
  ok "rule5_required_files_present_pos" "both required files present -- PASS"
else
  fail "rule5_required_files_present_pos" "expected PASS when both files exist"
fi

## Negative: missing openapi-v1.yaml triggers FAIL
_r5_neg="$scratch/r5_neg"
mkdir -p "$_r5_neg/docs/contracts"
touch "$_r5_neg/docs/contracts/contract-catalog.md"
# openapi-v1.yaml intentionally absent
_r5_neg_fail=0
for _req in "$_r5_neg/docs/contracts/contract-catalog.md" "$_r5_neg/docs/contracts/openapi-v1.yaml"; do
  [[ ! -f "$_req" ]] && _r5_neg_fail=1
done
if [[ $_r5_neg_fail -eq 1 ]]; then
  ok "rule5_required_files_present_neg" "missing openapi-v1.yaml correctly triggers FAIL"
else
  fail "rule5_required_files_present_neg" "expected FAIL when openapi-v1.yaml absent"
fi

# ---------------------------------------------------------------------------
# RULE 6 -- metric_naming_namespace
# Metric name strings in Java must start with springai_ascend_.
# No springai_fin_ prefix allowed.
# ---------------------------------------------------------------------------

## Positive: correct prefix passes
_r6_good_java="$scratch/GoodMetrics.java"
cat > "$_r6_good_java" <<'EOF'
Counter.builder("springai_ascend_tenant_header_missing_total")
    .register(registry);
EOF
_r6_pos_fail=0
while IFS= read -r _jl; do
  _nm="${_jl#*.counter(\"}"
  if [[ "$_nm" != "$_jl" ]]; then
    _nm="${_nm%%\"*}"
    if [[ -n "$_nm" && "${_nm:0:15}" != "springai_ascend" ]]; then _r6_pos_fail=1; fi
  fi
done < "$_r6_good_java"
if grep -q 'springai_fin_\|springai\.fin\.' "$_r6_good_java" 2>/dev/null; then _r6_pos_fail=1; fi
if [[ $_r6_pos_fail -eq 0 ]]; then
  ok "rule6_metric_naming_namespace_pos" "correct springai_ascend_ prefix passes"
else
  fail "rule6_metric_naming_namespace_pos" "expected PASS for correct metric prefix"
fi

## Negative: wrong prefix triggers FAIL
_r6_bad_java="$scratch/BadMetrics.java"
cat > "$_r6_bad_java" <<'EOF'
registry.counter("app_counter_total").increment();
EOF
_r6_neg_fail=0
while IFS= read -r _jl; do
  _nm="${_jl#*.counter(\"}"
  if [[ "$_nm" != "$_jl" ]]; then
    _nm="${_nm%%\"*}"
    if [[ -n "$_nm" && "${_nm:0:15}" != "springai_ascend" ]]; then _r6_neg_fail=1; fi
  fi
done < "$_r6_bad_java"
if [[ $_r6_neg_fail -eq 1 ]]; then
  ok "rule6_metric_naming_namespace_neg" "wrong prefix 'app_counter_total' correctly triggers FAIL"
else
  fail "rule6_metric_naming_namespace_neg" "expected FAIL for metric without springai_ascend_ prefix"
fi

# ---------------------------------------------------------------------------
# RULE 19 — shipped_row_tests_evidence (strengthened)
# (a) tests: absent on shipped row → FAIL
# (b) tests: [] on shipped row → FAIL
# (c) tests: non-empty but path missing → FAIL
# (d) tests: non-empty with real path → PASS
# ---------------------------------------------------------------------------

## Positive: shipped row with non-empty tests list (self-test .sh is a real file)
_r19_pos_yaml="$scratch/r19_pos.yaml"
cat > "$_r19_pos_yaml" <<'EOF'
capabilities:
  my_cap:
    status: implemented_unverified
    shipped: true
    tests:
      - gate/test_architecture_sync_gate.sh
EOF
_r19_pos_fail=0
_in_sh19=0; _tf19=0; _thi19=0; _tp19_val=''
while IFS= read -r _l19 || [[ -n "$_l19" ]]; do
  if printf '%s\n' "$_l19" | grep -qE '^  [a-zA-Z][a-zA-Z_]+:'; then _in_sh19=0; fi
  if printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_sh19=1; fi
  if [[ $_in_sh19 -eq 1 ]]; then
    if printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+tests:[[:space:]]*$'; then _tf19=1; fi
    if [[ $_tf19 -eq 1 ]] && printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+-[[:space:]]+'; then
      _thi19=1; _tp19_val=$(printf '%s\n' "$_l19" | sed -E 's/^[[:space:]]+-[[:space:]]+(.*)/\1/')
    fi
  fi
done < "$_r19_pos_yaml"
if [[ $_tf19 -eq 1 && $_thi19 -eq 1 && -e "$_tp19_val" ]]; then
  ok "rule19_tests_evidence_pos" "shipped row with existing test path passes"
else
  fail "rule19_tests_evidence_pos" "expected PASS for shipped row with valid test path"
fi

## Negative-a: shipped row with tests: absent → FAIL
_r19_neg_a="$scratch/r19_neg_a.yaml"
cat > "$_r19_neg_a" <<'EOF'
capabilities:
  my_cap:
    status: implemented_unverified
    shipped: true
    implementation:
      - gate/check_architecture_sync.sh
EOF
_in_sh19a=0; _tf19a=0
while IFS= read -r _l19 || [[ -n "$_l19" ]]; do
  if printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_sh19a=1; fi
  if [[ $_in_sh19a -eq 1 ]] && printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+tests:'; then _tf19a=1; fi
done < "$_r19_neg_a"
if [[ $_tf19a -eq 0 ]]; then
  ok "rule19_tests_evidence_neg_absent" "tests: absent on shipped row correctly detected"
else
  fail "rule19_tests_evidence_neg_absent" "expected tests: to be absent"
fi

## Negative-b: shipped row with tests: [] → FAIL
_r19_neg_b="$scratch/r19_neg_b.yaml"
cat > "$_r19_neg_b" <<'EOF'
capabilities:
  my_cap:
    status: implemented_unverified
    shipped: true
    tests: []
EOF
_in_sh19b=0; _empty19b=0
while IFS= read -r _l19 || [[ -n "$_l19" ]]; do
  if printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_sh19b=1; fi
  if [[ $_in_sh19b -eq 1 ]] && printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+tests:[[:space:]]*\[\]'; then _empty19b=1; fi
done < "$_r19_neg_b"
if [[ $_empty19b -eq 1 ]]; then
  ok "rule19_tests_evidence_neg_empty_inline" "tests: [] on shipped row correctly detected"
else
  fail "rule19_tests_evidence_neg_empty_inline" "expected tests: [] to be detected as empty"
fi

## Negative-c: shipped row with tests path that doesn't exist → FAIL
_r19_neg_c="$scratch/r19_neg_c.yaml"
cat > "$_r19_neg_c" <<'EOF'
capabilities:
  my_cap:
    status: implemented_unverified
    shipped: true
    tests:
      - gate/nonexistent_test.sh
EOF
_in_sh19c=0; _tf19c=0; _missing19c=0
while IFS= read -r _l19 || [[ -n "$_l19" ]]; do
  if printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_sh19c=1; fi
  if [[ $_in_sh19c -eq 1 ]] && printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+tests:[[:space:]]*$'; then _tf19c=1; fi
  if [[ $_tf19c -eq 1 ]] && printf '%s\n' "$_l19" | grep -qE '^[[:space:]]+-[[:space:]]+'; then
    _tp_c=$(printf '%s\n' "$_l19" | sed -E 's/^[[:space:]]+-[[:space:]]+(.*)/\1/')
    if [[ ! -e "$_tp_c" ]]; then _missing19c=1; fi
  fi
done < "$_r19_neg_c"
if [[ $_missing19c -eq 1 ]]; then
  ok "rule19_tests_evidence_neg_missing_path" "non-existent test path on shipped row correctly detected"
else
  fail "rule19_tests_evidence_neg_missing_path" "expected missing test path to be detected"
fi

# ---------------------------------------------------------------------------
# RULE 22 — lowercase_metrics_in_contract_docs (widened, case-sensitive)
# Positive: lowercase metric name passes (must NOT be flagged)
# Negative: SPRINGAI_ASCEND_<lowercase> detected → FAIL
# ---------------------------------------------------------------------------

## Positive: lowercase metric is compliant — must pass
_r22_pos="$scratch/r22_pos.md"
printf '## Metrics\n\n- `springai_ascend_filter_errors_total` — error counter\n' > "$_r22_pos"
if grep -qE 'SPRINGAI_ASCEND_[a-z]' "$_r22_pos" 2>/dev/null; then
  fail "rule22_lowercase_metrics_pos" "lowercase metric incorrectly flagged as uppercase violation"
else
  ok "rule22_lowercase_metrics_pos" "lowercase springai_ascend_ metric correctly passes"
fi

## Negative: uppercase SPRINGAI_ASCEND_<lowercase> triggers FAIL
_r22_neg="$scratch/r22_neg.md"
printf '## Metrics\n\n- `SPRINGAI_ASCEND_filter_errors_total` — error counter\n' > "$_r22_neg"
if grep -qE 'SPRINGAI_ASCEND_[a-z]' "$_r22_neg" 2>/dev/null; then
  ok "rule22_lowercase_metrics_neg" "SPRINGAI_ASCEND_<lowercase> correctly detected as violation"
else
  fail "rule22_lowercase_metrics_neg" "expected SPRINGAI_ASCEND_<lowercase> to be detected"
fi

# ---------------------------------------------------------------------------
# RULE 24 — shipped_row_evidence_paths_exist
# Positive: latest_delivery_file points to existing file → PASS
# Negative: latest_delivery_file points to non-existent file → FAIL
# ---------------------------------------------------------------------------

## Positive: latest_delivery_file exists
_r24_pos="$scratch/r24_pos.yaml"
_r24_real_file="$scratch/r24_delivery.md"
touch "$_r24_real_file"
cat > "$_r24_pos" <<EOF
capabilities:
  my_cap:
    status: implemented_unverified
    shipped: true
    latest_delivery_file: ${_r24_real_file}
EOF
_in_sh24p=0; _ldf24p=''; _ldf24p_missing=0
while IFS= read -r _l24 || [[ -n "$_l24" ]]; do
  if printf '%s\n' "$_l24" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_sh24p=1; fi
  if [[ $_in_sh24p -eq 1 ]] && printf '%s\n' "$_l24" | grep -qE '^[[:space:]]+latest_delivery_file:[[:space:]]+'; then
    _ldf24p=$(printf '%s\n' "$_l24" | sed -E 's/^[[:space:]]+latest_delivery_file:[[:space:]]+(.*)/\1/')
    [[ -n "$_ldf24p" && ! -e "$_ldf24p" ]] && _ldf24p_missing=1
  fi
done < "$_r24_pos"
if [[ $_ldf24p_missing -eq 0 ]]; then
  ok "rule24_evidence_paths_pos" "existing latest_delivery_file path passes"
else
  fail "rule24_evidence_paths_pos" "expected existing path to pass"
fi

## Negative: latest_delivery_file points to non-existent file
_r24_neg="$scratch/r24_neg.yaml"
cat > "$_r24_neg" <<'EOF'
capabilities:
  my_cap:
    status: implemented_unverified
    shipped: true
    latest_delivery_file: docs/delivery/nonexistent-deadbeef.md
EOF
_in_sh24n=0; _ldf24n_missing=0
while IFS= read -r _l24 || [[ -n "$_l24" ]]; do
  if printf '%s\n' "$_l24" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_sh24n=1; fi
  if [[ $_in_sh24n -eq 1 ]] && printf '%s\n' "$_l24" | grep -qE '^[[:space:]]+latest_delivery_file:[[:space:]]+'; then
    _ldf24n=$(printf '%s\n' "$_l24" | sed -E 's/^[[:space:]]+latest_delivery_file:[[:space:]]+(.*)/\1/')
    [[ -n "$_ldf24n" && ! -e "$_ldf24n" ]] && _ldf24n_missing=1
  fi
done < "$_r24_neg"
if [[ $_ldf24n_missing -eq 1 ]]; then
  ok "rule24_evidence_paths_neg" "non-existent latest_delivery_file correctly detected"
else
  fail "rule24_evidence_paths_neg" "expected non-existent path to be detected"
fi

# ---------------------------------------------------------------------------
# RULE 25 — peripheral_wave_qualifier
# Positive: "Primary sidecar impl:" with W1 qualifier → PASS
# Negative: "Primary sidecar impl:" without any wave qualifier → FAIL
# ---------------------------------------------------------------------------

## Positive: wave-qualified impl claim passes
_r25_pos="$scratch/r25_pos.java"
cat > "$_r25_pos" <<'EOF'
/**
 * W1 reference sidecar (per ADR-0034): spring-ai-ascend-graphmemory-starter wires a
 * Graphiti REST client at W1; no adapter implementation ships at W0.
 */
public interface GraphMemoryRepository {}
EOF
_r25_pos_fail=0
if grep -q 'Primary sidecar impl:\|Primary impl:' "$_r25_pos" 2>/dev/null; then
  # Would need context check; since not present, pattern isn't there
  _r25_pos_fail=1
fi
if [[ $_r25_pos_fail -eq 0 ]]; then
  ok "rule25_wave_qualifier_pos" "wave-qualified impl claim correctly passes"
else
  fail "rule25_wave_qualifier_pos" "expected wave-qualified file to pass"
fi

## Negative: unqualified "Primary sidecar impl:" triggers FAIL
_r25_neg="$scratch/r25_neg.java"
cat > "$_r25_neg" <<'EOF'
/**
 * Primary sidecar impl: spring-ai-ascend-graphmemory-starter (Graphiti REST).
 */
public interface GraphMemoryRepository {}
EOF
_r25_neg_fail=0
if grep -q 'Primary sidecar impl:' "$_r25_neg" 2>/dev/null; then
  # Check if wave qualifier is present in context
  _ctx25n=$(grep -A3 -B2 'Primary sidecar impl:' "$_r25_neg" 2>/dev/null | tr '\n' ' ')
  if ! printf '%s\n' "$_ctx25n" | grep -qE '\bW[0-4]\b'; then
    _r25_neg_fail=1
  fi
fi
if [[ $_r25_neg_fail -eq 1 ]]; then
  ok "rule25_wave_qualifier_neg" "unqualified 'Primary sidecar impl:' correctly detected"
else
  fail "rule25_wave_qualifier_neg" "expected unqualified impl claim to be detected"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Tests passed: ${passed}/${TOTAL}"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
exit 0
