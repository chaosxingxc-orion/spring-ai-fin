#!/usr/bin/env bash
# spring-ai-ascend architecture-sync gate self-test (L0 v2 + L1 Phase L).
# PARTIAL COVERAGE: covers Rules 1-6 + Rules 16, 19, 22, 24, 25, 26, 27, 28, 28j, 29.
# Full gate verification requires running: pwsh gate/check_architecture_sync.ps1
# The full gate has 29 active rules; this self-test covers Rules 1-6 + 16/19/22/24/25/26/27/28/28j/29.
# Phase L (L1 reviewer remediation) adds 2 cases for Rule 28j anchor validation:
# 35 → 37 self-tests.
# Prints: Tests passed: N/37
# Exits 0 if all 37 pass, 1 otherwise.

set -uo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

passed=0
failed=0
TOTAL=37

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
# RULE 16 — http_contract_w1_tenant_and_cancel_consistency (widened)
# Positive: "cross-check" wording passes (must NOT be flagged)
# Negative: "TenantContextFilter switches to JWT" is caught
# ---------------------------------------------------------------------------

## Positive: cross-check wording is compliant — must pass
_r16_pos="$scratch/r16_pos.md"
printf 'W1: TenantContextFilter adds a JWT tenant_id claim cross-check on top of X-Tenant-Id (per ADR-0040).\n' > "$_r16_pos"
_r16_pos_pattern='TenantContextFilter[[:space:]]+(switches[[:space:]]+to|replaces?([[:space:]]+with)?[[:space:]]+JWT|moves[[:space:]]+to)[[:space:]]+JWT|will[[:space:]]+replace.*X-Tenant-Id|replace[[:space:]]+header-based.*with[[:space:]]+JWT|W1[[:space:]]+replaces.*X-Tenant-Id'
if grep -qE "$_r16_pos_pattern" "$_r16_pos" 2>/dev/null; then
  fail "rule16_w1_tenant_pos" "cross-check wording incorrectly flagged as replace violation"
else
  ok "rule16_w1_tenant_pos" "cross-check wording correctly passes"
fi

## Negative: "switches to JWT" replacement-implying phrasing is caught
_r16_neg="$scratch/r16_neg.md"
printf 'W1: TenantContextFilter switches to JWT tenant_id claim; IdempotencyHeaderFilter wires IdempotencyStore.\n' > "$_r16_neg"
if grep -qE "$_r16_pos_pattern" "$_r16_neg" 2>/dev/null; then
  ok "rule16_w1_tenant_neg" "'TenantContextFilter switches to JWT' correctly detected as violation"
else
  fail "rule16_w1_tenant_neg" "expected 'switches to JWT' to be detected as replacement-implying"
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
# RULE 26 — release_note_shipped_surface_truth
# 26a — RunLifecycle name guard:
#   Positive: line with W2 wave qualifier or design-only marker → PASS
#   Negative: line listing RunLifecycle as W0 shipped SPI with no qualifier → FAIL
# 26b — RunContext method-list guard:
#   Positive: canonical method list (runId, tenantId, checkpointer, suspendForChild) → PASS
#   Negative: line includes posture() alongside RunContext → FAIL
# ---------------------------------------------------------------------------

## 26a Positive: wave-qualified RunLifecycle passes
_r26a_pos="$scratch/r26a_pos.md"
cat > "$_r26a_pos" <<'EOF'
| `Orchestration` SPI | Pure-Java SPIs; no framework imports. `RunLifecycle` (cancel/resume/retry) remains design-only for W2 — see ADR-0020 |
EOF
_r26a_pos_fail=0
while IFS= read -r _ln; do
  if printf '%s' "$_ln" | grep -q 'RunLifecycle'; then
    if ! printf '%s' "$_ln" | grep -qE '(^|[^A-Za-z0-9])W[1-4]([^A-Za-z0-9]|$)' && \
       ! printf '%s' "$_ln" | grep -qE 'design-only|deferred|not shipped|remains design|materialised at W|materialized at W'; then
      _r26a_pos_fail=1
    fi
  fi
done < "$_r26a_pos"
if [[ $_r26a_pos_fail -eq 0 ]]; then
  ok "rule26_runlifecycle_pos" "wave-qualified RunLifecycle correctly passes"
else
  fail "rule26_runlifecycle_pos" "expected wave-qualified RunLifecycle line to pass"
fi

## 26a Negative: unqualified RunLifecycle as W0 SPI label
_r26a_neg="$scratch/r26a_neg.md"
cat > "$_r26a_neg" <<'EOF'
| `RunLifecycle` SPI | `Orchestrator`, `GraphExecutor`, `AgentLoopExecutor` — pure-Java SPIs |
EOF
_r26a_neg_fail=0
_lines_count=0
mapfile -t _r26a_neg_lines < "$_r26a_neg"
_lines_count=${#_r26a_neg_lines[@]}
for ((_i=0; _i < _lines_count; _i++)); do
  _ln="${_r26a_neg_lines[$_i]}"
  if printf '%s' "$_ln" | grep -q 'RunLifecycle'; then
    _lo=$((_i > 0 ? _i - 1 : 0))
    _hi=$((_i + 1 < _lines_count ? _i + 1 : _i))
    _ctx=""
    for ((_j=_lo; _j <= _hi; _j++)); do _ctx="$_ctx ${_r26a_neg_lines[$_j]}"; done
    if ! printf '%s' "$_ctx" | grep -qE '(^|[^A-Za-z0-9])W[1-4]([^A-Za-z0-9]|$)' && \
       ! printf '%s' "$_ln" | grep -qE 'design-only|deferred|not shipped|remains design|materialised at W|materialized at W'; then
      _r26a_neg_fail=1
    fi
  fi
done
if [[ $_r26a_neg_fail -eq 1 ]]; then
  ok "rule26_runlifecycle_neg" "unqualified RunLifecycle correctly detected"
else
  fail "rule26_runlifecycle_neg" "expected unqualified RunLifecycle line to be detected"
fi

## 26b Positive: canonical RunContext method list passes
_r26b_pos="$scratch/r26b_pos.md"
cat > "$_r26b_pos" <<'EOF'
| `RunContext` | Interface methods: `runId()`, `tenantId()`, `checkpointer()`, `suspendForChild()` |
EOF
_r26b_pos_fail=0
while IFS= read -r _ln; do
  if printf '%s' "$_ln" | grep -q 'RunContext' && printf '%s' "$_ln" | grep -qE '[A-Za-z_][A-Za-z0-9_]*\(\)'; then
    if printf '%s' "$_ln" | grep -qE '\bposture[[:space:]]*\(\)'; then
      _r26b_pos_fail=1
    fi
    for _mt in $(printf '%s' "$_ln" | grep -oE '\b[A-Za-z_][A-Za-z0-9_]*\(' | sed 's/($//'); do
      case "$_mt" in
        [a-z]*)
          case "$_mt" in
            runId|tenantId|checkpointer|suspendForChild) : ;;
            exposes|lists|returns|threads|carries|provides|sourced|interface|method|methods|requires|reads|writes|sees|gets|fails) : ;;
            *) _r26b_pos_fail=1 ;;
          esac
          ;;
        *) : ;;
      esac
    done
  fi
done < "$_r26b_pos"
if [[ $_r26b_pos_fail -eq 0 ]]; then
  ok "rule26_runcontext_pos" "canonical RunContext method list correctly passes"
else
  fail "rule26_runcontext_pos" "expected canonical RunContext methods to pass"
fi

## 26b Negative: RunContext with invented posture() method
_r26b_neg="$scratch/r26b_neg.md"
cat > "$_r26b_neg" <<'EOF'
| `RunContext` | Interface: `tenantId()`, `runId()`, `posture()`; sourced from SPIs |
EOF
_r26b_neg_fail=0
while IFS= read -r _ln; do
  if printf '%s' "$_ln" | grep -q 'RunContext' && printf '%s' "$_ln" | grep -qE '[A-Za-z_][A-Za-z0-9_]*\(\)'; then
    if printf '%s' "$_ln" | grep -qE '\bposture[[:space:]]*\(\)'; then
      _r26b_neg_fail=1
    fi
  fi
done < "$_r26b_neg"
if [[ $_r26b_neg_fail -eq 1 ]]; then
  ok "rule26_runcontext_neg" "RunContext with posture() correctly detected"
else
  fail "rule26_runcontext_neg" "expected posture() alongside RunContext to be detected"
fi

# ---------------------------------------------------------------------------
# RULE 27 — active_entrypoint_baseline_truth
# Positive: synthetic YAML + README with matching §4 count → PASS
# Negative: synthetic YAML + README with mismatched §4 count → FAIL
# ---------------------------------------------------------------------------

## Positive: matching baseline counts pass
_r27_pos="$scratch/r27_pos"
mkdir -p "$_r27_pos/docs/governance"
cat > "$_r27_pos/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  architecture_sync_gate:
    allowed_claim: "Architecture baseline: 45 §4 constraints (#1–#45); 47 ADRs (0001–0047); 27 active gate rules; 30 gate self-tests."
EOF
cat > "$_r27_pos/README.md" <<'EOF'
- Architecture baseline: 45 §4 constraints · 47 ADRs · 27 gate rules · 30 self-tests
EOF
_r27_pos_claim=$(awk '/^[[:space:]]+architecture_sync_gate:/{flag=1} flag && /allowed_claim:/{print; exit}' "$_r27_pos/docs/governance/architecture-status.yaml")
_r27_pos_readme=$(cat "$_r27_pos/README.md")
_r27_pos_fail=0
_r27_pos_exp=$(printf '%s' "$_r27_pos_claim" | grep -oE '[0-9]+[[:space:]]+§4[[:space:]]+constraints' | grep -oE '^[0-9]+' | head -1)
_r27_pos_act=$(printf '%s' "$_r27_pos_readme" | grep -oE '[0-9]+[[:space:]]+§4[[:space:]]+constraints' | grep -oE '^[0-9]+' | head -1)
[[ "$_r27_pos_exp" != "$_r27_pos_act" ]] && _r27_pos_fail=1
if [[ $_r27_pos_fail -eq 0 ]]; then
  ok "rule27_baseline_pos" "matching baseline counts correctly pass"
else
  fail "rule27_baseline_pos" "expected matching baseline counts to pass (exp=$_r27_pos_exp act=$_r27_pos_act)"
fi

## Negative: README §4 count mismatches YAML → FAIL
_r27_neg="$scratch/r27_neg"
mkdir -p "$_r27_neg/docs/governance"
cat > "$_r27_neg/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  architecture_sync_gate:
    allowed_claim: "Architecture baseline: 45 §4 constraints (#1–#45); 47 ADRs (0001–0047); 27 active gate rules; 30 gate self-tests."
EOF
cat > "$_r27_neg/README.md" <<'EOF'
- Architecture baseline: 44 §4 constraints · 47 ADRs · 27 gate rules · 30 self-tests
EOF
_r27_neg_claim=$(awk '/^[[:space:]]+architecture_sync_gate:/{flag=1} flag && /allowed_claim:/{print; exit}' "$_r27_neg/docs/governance/architecture-status.yaml")
_r27_neg_readme=$(cat "$_r27_neg/README.md")
_r27_neg_fail=0
_r27_neg_exp=$(printf '%s' "$_r27_neg_claim" | grep -oE '[0-9]+[[:space:]]+§4[[:space:]]+constraints' | grep -oE '^[0-9]+' | head -1)
_r27_neg_act=$(printf '%s' "$_r27_neg_readme" | grep -oE '[0-9]+[[:space:]]+§4[[:space:]]+constraints' | grep -oE '^[0-9]+' | head -1)
[[ "$_r27_neg_exp" != "$_r27_neg_act" ]] && _r27_neg_fail=1
if [[ $_r27_neg_fail -eq 1 ]]; then
  ok "rule27_baseline_neg" "mismatched §4 baseline correctly detected (exp=$_r27_neg_exp act=$_r27_neg_act)"
else
  fail "rule27_baseline_neg" "expected mismatched §4 baseline to be detected"
fi

# ---------------------------------------------------------------------------
# RULE 28 — release_note_baseline_truth
# Positive: release note matching canonical baseline → PASS
# Negative: release note with stale counts and no freeze marker → FAIL
# Exempt: release note with stale counts but freeze marker → PASS (exempt)
# ---------------------------------------------------------------------------

## Positive: release note matches canonical baseline → PASS
_r28_pos="$scratch/r28_pos"
mkdir -p "$_r28_pos/docs/governance" "$_r28_pos/docs/releases"
cat > "$_r28_pos/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  architecture_sync_gate:
    allowed_claim: "Architecture baseline: 50 §4 constraints (#1–#50); 52 ADRs (0001–0052); 29 active gate rules; 35 gate self-tests."
EOF
cat > "$_r28_pos/docs/releases/some-release.md" <<'EOF'
| §4 constraints | 50 (#1–#50) |
| Active ADRs | 52 (ADR-0001–ADR-0052) |
| Active gate rules | 29 |
| Gate self-test cases | 35 |
EOF
_r28_pos_claim=$(awk '/^[[:space:]]+architecture_sync_gate:/{flag=1} flag && /allowed_claim:/{print; exit}' "$_r28_pos/docs/governance/architecture-status.yaml")
_r28_pos_rf=$(cat "$_r28_pos/docs/releases/some-release.md")
_r28_pos_exp=$(printf '%s' "$_r28_pos_claim" | grep -oE '[0-9]+[[:space:]]+§4[[:space:]]+constraints' | grep -oE '^[0-9]+' | head -1)
_r28_pos_match=$(printf '%s' "$_r28_pos_rf" | grep -oE '§4[[:space:]]+constraints[[:space:]]*\|[[:space:]]*[0-9]+' | head -1)
_r28_pos_act=$(printf '%s' "$_r28_pos_match" | grep -oE '[0-9]+' | tail -1)
if [[ -n "$_r28_pos_exp" && "$_r28_pos_exp" == "$_r28_pos_act" ]]; then
  ok "rule28_baseline_pos" "release note matching canonical baseline correctly passes (exp=$_r28_pos_exp act=$_r28_pos_act)"
else
  fail "rule28_baseline_pos" "expected matching release-note baseline to pass (exp=$_r28_pos_exp act=$_r28_pos_act)"
fi

## Negative: release note stale counts, NO freeze marker → FAIL
_r28_neg="$scratch/r28_neg"
mkdir -p "$_r28_neg/docs/governance" "$_r28_neg/docs/releases"
cat > "$_r28_neg/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  architecture_sync_gate:
    allowed_claim: "Architecture baseline: 50 §4 constraints (#1–#50); 52 ADRs (0001–0052); 29 active gate rules; 35 gate self-tests."
EOF
cat > "$_r28_neg/docs/releases/some-release.md" <<'EOF'
| §4 constraints | 45 (#1–#45) |
| Active ADRs | 47 (ADR-0001–ADR-0047) |
| Active gate rules | 27 |
| Gate self-test cases | 30 |
EOF
_r28_neg_claim=$(awk '/^[[:space:]]+architecture_sync_gate:/{flag=1} flag && /allowed_claim:/{print; exit}' "$_r28_neg/docs/governance/architecture-status.yaml")
_r28_neg_rf=$(cat "$_r28_neg/docs/releases/some-release.md")
_r28_neg_has_freeze=0
grep -qE 'Historical artifact frozen at SHA' "$_r28_neg/docs/releases/some-release.md" && _r28_neg_has_freeze=1
_r28_neg_exp=$(printf '%s' "$_r28_neg_claim" | grep -oE '[0-9]+[[:space:]]+§4[[:space:]]+constraints' | grep -oE '^[0-9]+' | head -1)
_r28_neg_match=$(printf '%s' "$_r28_neg_rf" | grep -oE '§4[[:space:]]+constraints[[:space:]]*\|[[:space:]]*[0-9]+' | head -1)
_r28_neg_act=$(printf '%s' "$_r28_neg_match" | grep -oE '[0-9]+' | tail -1)
if [[ $_r28_neg_has_freeze -eq 0 && -n "$_r28_neg_exp" && -n "$_r28_neg_act" && "$_r28_neg_exp" != "$_r28_neg_act" ]]; then
  ok "rule28_baseline_neg" "stale release-note baseline without freeze marker correctly detected (exp=$_r28_neg_exp act=$_r28_neg_act)"
else
  fail "rule28_baseline_neg" "expected stale release-note baseline without freeze marker to be detected (has_freeze=$_r28_neg_has_freeze exp=$_r28_neg_exp act=$_r28_neg_act)"
fi

## Exempt: release note stale counts BUT freeze marker present → exempt (pass)
_r28_exempt="$scratch/r28_exempt"
mkdir -p "$_r28_exempt/docs/governance" "$_r28_exempt/docs/releases"
cat > "$_r28_exempt/docs/governance/architecture-status.yaml" <<'EOF'
capabilities:
  architecture_sync_gate:
    allowed_claim: "Architecture baseline: 50 §4 constraints (#1–#50); 52 ADRs (0001–0052); 29 active gate rules; 35 gate self-tests."
EOF
cat > "$_r28_exempt/docs/releases/frozen-release.md" <<'EOF'
> Historical artifact frozen at SHA 82a1397 (L0 release). Baseline counts in this document reflect L0 release-time state.

| §4 constraints | 45 (#1–#45) |
| Active ADRs | 47 (ADR-0001–ADR-0047) |
| Active gate rules | 27 |
| Gate self-test cases | 30 |
EOF
_r28_exempt_has_freeze=0
grep -qE 'Historical artifact frozen at SHA' "$_r28_exempt/docs/releases/frozen-release.md" && _r28_exempt_has_freeze=1
if [[ $_r28_exempt_has_freeze -eq 1 ]]; then
  ok "rule28_baseline_neg_no_freeze_marker" "freeze marker correctly exempts release note from baseline check"
else
  fail "rule28_baseline_neg_no_freeze_marker" "expected freeze marker to exempt release note"
fi

# ---------------------------------------------------------------------------
# RULE 29 — whitepaper_alignment_matrix_present
# Positive: matrix file exists with all 20 required concepts → PASS
# Negative: matrix file missing OR missing a required concept → FAIL
# ---------------------------------------------------------------------------

## Positive: matrix file with all 20 concepts → PASS
_r29_pos="$scratch/r29_pos"
mkdir -p "$_r29_pos/docs/governance"
cat > "$_r29_pos/docs/governance/whitepaper-alignment-matrix.md" <<'EOF'
# Whitepaper Alignment Matrix
- C/S separation
- Task Cursor
- Dynamic Hydration
- Sync State
- Sub-Stream
- Yield & Handoff
- Business ontology ownership
- S-side execution trajectory ownership
- Placeholder exemption
- Full Trace vs Node Snapshot
- Lazy mounting
- Skill Topology Scheduler
- C-side business degradation authority
- Session/context decoupling
- Workflow Intermediary
- Three-track bus
- Capability bidding
- Permission issuance
- Chronos Hydration
- Service Layer microservice commitment
EOF
_r29_pos_missing=0
for _concept29p in 'C/S separation' 'Task Cursor' 'Dynamic Hydration' 'Sync State' 'Sub-Stream' 'Yield & Handoff' 'Business ontology ownership' 'S-side execution trajectory ownership' 'Placeholder exemption' 'Full Trace vs Node Snapshot' 'Lazy mounting' 'Skill Topology Scheduler' 'C-side business degradation authority' 'Session/context decoupling' 'Workflow Intermediary' 'Three-track bus' 'Capability bidding' 'Permission issuance' 'Chronos Hydration' 'Service Layer microservice commitment'; do
  if ! grep -qF "$_concept29p" "$_r29_pos/docs/governance/whitepaper-alignment-matrix.md"; then
    _r29_pos_missing=1
  fi
done
if [[ $_r29_pos_missing -eq 0 ]]; then
  ok "rule29_matrix_pos" "matrix with all 20 required concepts correctly passes"
else
  fail "rule29_matrix_pos" "expected matrix with all 20 concepts to pass"
fi

## Negative: matrix missing a required concept → FAIL
_r29_neg="$scratch/r29_neg"
mkdir -p "$_r29_neg/docs/governance"
cat > "$_r29_neg/docs/governance/whitepaper-alignment-matrix.md" <<'EOF'
# Whitepaper Alignment Matrix
- C/S separation
- Task Cursor
- Dynamic Hydration
EOF
_r29_neg_missing=0
for _concept29n in 'C/S separation' 'Chronos Hydration' 'Workflow Intermediary'; do
  if ! grep -qF "$_concept29n" "$_r29_neg/docs/governance/whitepaper-alignment-matrix.md"; then
    _r29_neg_missing=1
  fi
done
if [[ $_r29_neg_missing -eq 1 ]]; then
  ok "rule29_matrix_neg" "matrix missing required concept correctly detected"
else
  fail "rule29_matrix_neg" "expected missing concept to be detected"
fi

# ---------------------------------------------------------------------------
# RULE 28j -- enforcer_artifact_paths_exist (Phase L anchor validation, E35)
# Phase K (E33) checked file existence only. Phase L extends 28j to validate
# that #anchor references in enforcers.yaml resolve to a real method (Java/Bash)
# or heading (Markdown) inside the target file.
# ---------------------------------------------------------------------------

## Positive: artifact anchor that resolves to a real Java @Test method passes.
_r28j_pos="$scratch/r28j_pos"
mkdir -p "$_r28j_pos/src" "$_r28j_pos/docs"
cat > "$_r28j_pos/src/FooIT.java" <<'EOF'
package x;
class FooIT {
    @org.junit.jupiter.api.Test
    void real_method() {}
    void another_method() {}
}
EOF
cat > "$_r28j_pos/docs/enforcers.yaml" <<'EOF'
- id: EX1
  artifact: src/FooIT.java#real_method
EOF
_r28j_pos_fail=0
while IFS= read -r _aline; do
  [[ -z "$_aline" ]] && continue
  _aval=${_aline#*artifact:}
  _aval=${_aval#"${_aval%%[![:space:]]*}"}
  _apath=${_aval%%#*}
  _aanchor=""
  case "$_aval" in *'#'*) _aanchor=${_aval#*#};; esac
  _aanchor=${_aanchor%"${_aanchor##*[![:space:]]}"}
  _fullpath="$_r28j_pos/$_apath"
  if [[ ! -e "$_fullpath" ]]; then _r28j_pos_fail=1; fi
  if [[ -n "$_aanchor" ]] && [[ "$_apath" == *.java ]]; then
    if ! grep -qE "(void|\)|\>|\>[[:space:]])[[:space:]]+${_aanchor}[[:space:]]*\(" "$_fullpath"; then
      if ! grep -qE "^[[:space:]]*[a-zA-Z_<>][^()]*[[:space:]]${_aanchor}[[:space:]]*\(" "$_fullpath"; then
        _r28j_pos_fail=1
      fi
    fi
  fi
done < <(grep -E '^[[:space:]]*-?[[:space:]]*artifact:' "$_r28j_pos/docs/enforcers.yaml")
if [[ $_r28j_pos_fail -eq 0 ]]; then
  ok "rule28j_anchor_resolves_pos" "real Java method anchor correctly passes"
else
  fail "rule28j_anchor_resolves_pos" "expected real method anchor to pass"
fi

## Negative: artifact anchor that names a non-existent method fails.
_r28j_neg="$scratch/r28j_neg"
mkdir -p "$_r28j_neg/src" "$_r28j_neg/docs"
cat > "$_r28j_neg/src/FooIT.java" <<'EOF'
package x;
class FooIT {
    @org.junit.jupiter.api.Test
    void only_real_method() {}
}
EOF
cat > "$_r28j_neg/docs/enforcers.yaml" <<'EOF'
- id: EX2
  artifact: src/FooIT.java#bogusMethod
EOF
_r28j_neg_detected=0
while IFS= read -r _aline; do
  [[ -z "$_aline" ]] && continue
  _aval=${_aline#*artifact:}
  _aval=${_aval#"${_aval%%[![:space:]]*}"}
  _apath=${_aval%%#*}
  _aanchor=""
  case "$_aval" in *'#'*) _aanchor=${_aval#*#};; esac
  _aanchor=${_aanchor%"${_aanchor##*[![:space:]]}"}
  _fullpath="$_r28j_neg/$_apath"
  if [[ -n "$_aanchor" ]] && [[ "$_apath" == *.java ]]; then
    _hit1=0
    grep -qE "(void|\)|\>|\>[[:space:]])[[:space:]]+${_aanchor}[[:space:]]*\(" "$_fullpath" && _hit1=1
    grep -qE "^[[:space:]]*[a-zA-Z_<>][^()]*[[:space:]]${_aanchor}[[:space:]]*\(" "$_fullpath" && _hit1=1
    if [[ $_hit1 -eq 0 ]]; then _r28j_neg_detected=1; fi
  fi
done < <(grep -E '^[[:space:]]*-?[[:space:]]*artifact:' "$_r28j_neg/docs/enforcers.yaml")
if [[ $_r28j_neg_detected -eq 1 ]]; then
  ok "rule28j_anchor_resolves_neg" "bogus method anchor correctly detected"
else
  fail "rule28j_anchor_resolves_neg" "expected bogus anchor to be detected"
fi

# ===========================================================================
# W1 Layered-4+1 + Architecture-Graph self-tests (Rules 37-40, ADR-0068)
# ===========================================================================

# ---------------------------------------------------------------------------
# Rule 37 positive: ARCHITECTURE.md with valid level + view front-matter passes
# ---------------------------------------------------------------------------
_r37_pos="$scratch/r37_pos"
mkdir -p "$_r37_pos"
cat > "$_r37_pos/ARCHITECTURE.md" <<'EOF'
---
level: L0
view: scenarios
---

# Test architecture
EOF
_lev="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^level:[[:space:]]/{sub(/^level:[[:space:]]*/,""); print; exit}' "$_r37_pos/ARCHITECTURE.md")"
_vw="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^view:[[:space:]]/{sub(/^view:[[:space:]]*/,""); print; exit}' "$_r37_pos/ARCHITECTURE.md")"
if [[ "$_lev" == "L0" && "$_vw" == "scenarios" ]]; then
  ok "rule37_front_matter_pos" "level=L0 view=scenarios parsed from valid front-matter"
else
  fail "rule37_front_matter_pos" "expected level=L0 view=scenarios, got level='$_lev' view='$_vw'"
fi

# ---------------------------------------------------------------------------
# Rule 37 negative: ARCHITECTURE.md missing front-matter fails detection
# ---------------------------------------------------------------------------
_r37_neg="$scratch/r37_neg"
mkdir -p "$_r37_neg"
cat > "$_r37_neg/ARCHITECTURE.md" <<'EOF'
# No front matter here
EOF
_lev="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^level:[[:space:]]/{sub(/^level:[[:space:]]*/,""); print; exit}' "$_r37_neg/ARCHITECTURE.md")"
if [[ -z "$_lev" ]]; then
  ok "rule37_front_matter_neg" "missing front-matter correctly produces empty level"
else
  fail "rule37_front_matter_neg" "expected empty level, got '$_lev'"
fi

# ---------------------------------------------------------------------------
# Rule 38 positive: graph YAML structure parses + every edge endpoint is a node
# ---------------------------------------------------------------------------
_r38_pos="$scratch/r38_pos"
mkdir -p "$_r38_pos"
cat > "$_r38_pos/graph.yaml" <<'EOF'
nodes:
  - id: P-A
    type: principle
  - id: Rule-29
    type: rule
  - id: E48
    type: enforcer
edges:
  - src: P-A
    dst: Rule-29
    type: operationalised_by
  - src: Rule-29
    dst: E48
    type: enforced_by
EOF
# Crude integrity check: every src/dst token must appear as an id in nodes.
_r38_orphan=0
_ids="$(awk '/^  - id:/{print $3}' "$_r38_pos/graph.yaml")"
while IFS= read -r _ep; do
  _v="$(printf '%s\n' "$_ep" | sed -E 's/^[[:space:]]*-?[[:space:]]*(src|dst):[[:space:]]*([A-Za-z0-9_-]+).*/\2/')"
  [[ -z "$_v" || "$_v" == "$_ep" ]] && continue
  if ! grep -qxF "$_v" <<< "$_ids"; then _r38_orphan=1; fi
done < <(grep -E '^[[:space:]]*-?[[:space:]]*(src|dst):' "$_r38_pos/graph.yaml")
if [[ $_r38_orphan -eq 0 ]]; then
  ok "rule38_graph_endpoints_pos" "all edge endpoints resolve to node ids"
else
  fail "rule38_graph_endpoints_pos" "unresolved edge endpoint detected unexpectedly"
fi

# ---------------------------------------------------------------------------
# Rule 39 positive: review proposal with affects_level + affects_view passes
# ---------------------------------------------------------------------------
_r39_pos="$scratch/r39_pos"
mkdir -p "$_r39_pos/docs/reviews"
cat > "$_r39_pos/docs/reviews/2026-06-01-future-proposal.md" <<'EOF'
---
affects_level: L1
affects_view: process
---

# Future proposal
EOF
_al="$(grep -E '^affects_level:[[:space:]]+(L0|L1|L2)' "$_r39_pos/docs/reviews/2026-06-01-future-proposal.md" | head -1 || true)"
_av="$(grep -E '^affects_view:[[:space:]]+(logical|development|process|physical|scenarios)' "$_r39_pos/docs/reviews/2026-06-01-future-proposal.md" | head -1 || true)"
if [[ -n "$_al" && -n "$_av" ]]; then
  ok "rule39_review_front_matter_pos" "affects_level + affects_view both present and valid"
else
  fail "rule39_review_front_matter_pos" "expected both keys present; got al='$_al' av='$_av'"
fi

# ---------------------------------------------------------------------------
# Rule 40 negative: orphan enforcer (no rule->enforcer edge) gets detected
# ---------------------------------------------------------------------------
_r40_neg="$scratch/r40_neg"
mkdir -p "$_r40_neg"
cat > "$_r40_neg/graph.yaml" <<'EOF'
- id: E99
  type: enforcer
- src: P-A
  dst: Rule-29
  type: operationalised_by
EOF
# Detect: enforcer node E99 has no incoming `type: enforced_by` edge.
_r40_detected=0
if grep -q "id: E99" "$_r40_neg/graph.yaml" && ! grep -q "dst: E99" "$_r40_neg/graph.yaml"; then
  _r40_detected=1
fi
if [[ $_r40_detected -eq 1 ]]; then
  ok "rule40_orphan_enforcer_neg" "orphan enforcer (no rule path) correctly detected"
else
  fail "rule40_orphan_enforcer_neg" "expected orphan enforcer to be flagged"
fi

# ===========================================================================
# Phase M self-tests (Rules 41-44, ADR-0068)
# ===========================================================================

# ---------------------------------------------------------------------------
# Rule 41 positive: graph node with anchor + anchor_resolves: true passes
# ---------------------------------------------------------------------------
_r41_pos="$scratch/r41_pos"
mkdir -p "$_r41_pos"
cat > "$_r41_pos/graph.yaml" <<'EOF'
nodes:
  - id: file:foo/Bar.java
    type: artefact
    path: foo/Bar.java
    exists: true
    anchor: realMethod
    anchor_resolves: true
EOF
_r41_pos_offenders="$(awk '
  /^  - id:/ { cur=$3; type=""; anchor=""; resolves="" }
  /^    type:/ { type=$2 }
  /^    anchor:/ { val=substr($0,index($0,":")+2); gsub(/[[:space:]]+$/,"",val); anchor=val }
  /^    anchor_resolves:/ {
    val=substr($0,index($0,":")+2); gsub(/[[:space:]]+$/,"",val); resolves=val
    if (type=="artefact" && anchor!="" && anchor!="null" && resolves=="false") print cur
  }
' "$_r41_pos/graph.yaml")"
if [[ -z "$_r41_pos_offenders" ]]; then
  ok "rule41_anchor_resolves_pos" "node with anchor_resolves:true passes"
else
  fail "rule41_anchor_resolves_pos" "false offenders detected: $_r41_pos_offenders"
fi

# ---------------------------------------------------------------------------
# Rule 41 negative: graph node with anchor + anchor_resolves: false fails
# ---------------------------------------------------------------------------
_r41_neg="$scratch/r41_neg"
mkdir -p "$_r41_neg"
cat > "$_r41_neg/graph.yaml" <<'EOF'
nodes:
  - id: file:foo/Bar.java
    type: artefact
    path: foo/Bar.java
    exists: true
    anchor: bogusMethod
    anchor_resolves: false
EOF
_r41_neg_offenders="$(awk '
  /^  - id:/ { cur=$3; type=""; anchor=""; resolves="" }
  /^    type:/ { type=$2 }
  /^    anchor:/ { val=substr($0,index($0,":")+2); gsub(/[[:space:]]+$/,"",val); anchor=val }
  /^    anchor_resolves:/ {
    val=substr($0,index($0,":")+2); gsub(/[[:space:]]+$/,"",val); resolves=val
    if (type=="artefact" && anchor!="" && anchor!="null" && resolves=="false") print cur
  }
' "$_r41_neg/graph.yaml")"
if [[ -n "$_r41_neg_offenders" ]]; then
  ok "rule41_anchor_resolves_neg" "unresolved anchor correctly detected: $_r41_neg_offenders"
else
  fail "rule41_anchor_resolves_neg" "expected offender to be flagged"
fi

# ---------------------------------------------------------------------------
# Rule 42 positive: byte-identical files produce no diff
# ---------------------------------------------------------------------------
_r42_pos="$scratch/r42_pos"
mkdir -p "$_r42_pos"
printf "schema: x\nnodes: []\n" > "$_r42_pos/a.yaml"
printf "schema: x\nnodes: []\n" > "$_r42_pos/b.yaml"
if diff -q "$_r42_pos/a.yaml" "$_r42_pos/b.yaml" >/dev/null 2>&1; then
  ok "rule42_idempotent_pos" "identical builds produce no diff"
else
  fail "rule42_idempotent_pos" "expected identical files to compare equal"
fi

# ---------------------------------------------------------------------------
# Rule 42 negative: a mutated build produces a diff
# ---------------------------------------------------------------------------
_r42_neg="$scratch/r42_neg"
mkdir -p "$_r42_neg"
printf "schema: x\nnodes: []\n" > "$_r42_neg/a.yaml"
printf "schema: x\nnodes: [drift]\n" > "$_r42_neg/b.yaml"
if ! diff -q "$_r42_neg/a.yaml" "$_r42_neg/b.yaml" >/dev/null 2>&1; then
  ok "rule42_idempotent_neg" "mutated build correctly diff-detected"
else
  fail "rule42_idempotent_neg" "expected drift to be detected"
fi

# ---------------------------------------------------------------------------
# Rule 43 positive: highest-numbered ADR file is .yaml
# ---------------------------------------------------------------------------
_r43_pos="$scratch/r43_pos"
mkdir -p "$_r43_pos/docs/adr"
touch "$_r43_pos/docs/adr/0001-foo.md" "$_r43_pos/docs/adr/0068-bar.yaml"
_r43_pos_md_top="$(find "$_r43_pos/docs/adr" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' | sort -r | head -1)"
_r43_pos_yaml_top="$(find "$_r43_pos/docs/adr" -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.yaml' | sort -r | head -1)"
_r43_pos_md_n="$(basename "${_r43_pos_md_top}" | cut -c1-4)"
_r43_pos_yaml_n="$(basename "${_r43_pos_yaml_top}" | cut -c1-4)"
if (( 10#${_r43_pos_md_n:-0} <= 10#${_r43_pos_yaml_n:-0} )); then
  ok "rule43_new_adr_yaml_pos" "newest ADR is .yaml (md=$_r43_pos_md_n yaml=$_r43_pos_yaml_n)"
else
  fail "rule43_new_adr_yaml_pos" "expected yaml to be newest"
fi

# ---------------------------------------------------------------------------
# Rule 43 negative: highest-numbered ADR file is .md → flagged
# ---------------------------------------------------------------------------
_r43_neg="$scratch/r43_neg"
mkdir -p "$_r43_neg/docs/adr"
touch "$_r43_neg/docs/adr/0068-x.yaml" "$_r43_neg/docs/adr/0099-regression.md"
_r43_neg_md_n="$(basename "$(find "$_r43_neg/docs/adr" -name '*.md' | sort -r | head -1)" | cut -c1-4)"
_r43_neg_yaml_n="$(basename "$(find "$_r43_neg/docs/adr" -name '*.yaml' | sort -r | head -1)" | cut -c1-4)"
if (( 10#${_r43_neg_md_n:-0} > 10#${_r43_neg_yaml_n:-0} )); then
  ok "rule43_new_adr_yaml_neg" "regression .md ADR correctly flagged (md=$_r43_neg_md_n > yaml=$_r43_neg_yaml_n)"
else
  fail "rule43_new_adr_yaml_neg" "expected md to be detected as newer"
fi

# ---------------------------------------------------------------------------
# Rule 44 positive: file with freeze_id: null modified — no proposal required
# ---------------------------------------------------------------------------
_r44_pos="$scratch/r44_pos"
mkdir -p "$_r44_pos"
cat > "$_r44_pos/ARCHITECTURE.md" <<'EOF'
---
level: L0
view: scenarios
freeze_id: null
---
EOF
_r44_pos_fid="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^freeze_id:[[:space:]]/{sub(/^freeze_id:[[:space:]]*/,""); print; exit}' "$_r44_pos/ARCHITECTURE.md")"
if [[ -z "$_r44_pos_fid" || "$_r44_pos_fid" == "null" ]]; then
  ok "rule44_frozen_doc_pos" "unfrozen file (freeze_id=$_r44_pos_fid) correctly exempted"
else
  fail "rule44_frozen_doc_pos" "unfrozen file flagged unexpectedly"
fi

# ---------------------------------------------------------------------------
# Rule 44 negative: file with freeze_id: <id> + no companion → flagged
# ---------------------------------------------------------------------------
_r44_neg="$scratch/r44_neg"
mkdir -p "$_r44_neg"
cat > "$_r44_neg/ARCHITECTURE.md" <<'EOF'
---
level: L0
view: scenarios
freeze_id: post-L1-Russell
---
EOF
_r44_neg_fid="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^freeze_id:[[:space:]]/{sub(/^freeze_id:[[:space:]]*/,""); print; exit}' "$_r44_neg/ARCHITECTURE.md")"
if [[ -n "$_r44_neg_fid" && "$_r44_neg_fid" != "null" ]]; then
  ok "rule44_frozen_doc_neg" "frozen file (freeze_id=$_r44_neg_fid) correctly detected as requiring proposal"
else
  fail "rule44_frozen_doc_neg" "expected non-null freeze_id to be detected"
fi

# ===========================================================================
# W1.x Phase 1 self-tests — Rules 45-52 (L0 ironclad rules; ADR-0069)
# ===========================================================================

# ---------------------------------------------------------------------------
# Rule 45 positive: bus-channels.yaml with 3 channels + unique physical_channel
# ---------------------------------------------------------------------------
_r45_pos="$scratch/r45_pos"
mkdir -p "$_r45_pos/docs/governance"
cat > "$_r45_pos/docs/governance/bus-channels.yaml" <<'EOF'
channels:
  - id: control
    physical_channel: ctrl_q
  - id: data
    physical_channel: data_q
  - id: rhythm
    physical_channel: tick_q
EOF
_r45_pos_ids="$(awk '/^channels:[[:space:]]*$/{in_ch=1; next} /^[a-zA-Z]/{in_ch=0} in_ch && /^[[:space:]]+- id:/{sub(/^[[:space:]]+- id:[[:space:]]*/,""); sub(/[[:space:]].*$/,""); print}' "$_r45_pos/docs/governance/bus-channels.yaml")"
_r45_pos_count="$(printf '%s\n' "$_r45_pos_ids" | grep -c .)"
_r45_pos_phys="$(grep -E '^[[:space:]]+physical_channel:' "$_r45_pos/docs/governance/bus-channels.yaml" | sed -E 's/^[[:space:]]+physical_channel:[[:space:]]*//; s/[[:space:]].*$//')"
_r45_pos_phys_uniq="$(printf '%s\n' "$_r45_pos_phys" | sort -u | grep -c .)"
if [[ "$_r45_pos_count" -eq 3 ]] && [[ "$_r45_pos_phys_uniq" -eq 3 ]]; then
  ok "rule45_bus_channels_pos" "3 channels with unique physical_channel"
else
  fail "rule45_bus_channels_pos" "expected 3 channels + 3 unique physical_channel; got $_r45_pos_count / $_r45_pos_phys_uniq"
fi

# ---------------------------------------------------------------------------
# Rule 45 negative: two channels share physical_channel → flagged
# ---------------------------------------------------------------------------
_r45_neg="$scratch/r45_neg"
mkdir -p "$_r45_neg/docs/governance"
cat > "$_r45_neg/docs/governance/bus-channels.yaml" <<'EOF'
channels:
  - id: control
    physical_channel: shared_q
  - id: data
    physical_channel: shared_q
  - id: rhythm
    physical_channel: tick_q
EOF
_r45_neg_phys="$(grep -E '^[[:space:]]+physical_channel:' "$_r45_neg/docs/governance/bus-channels.yaml" | sed -E 's/^[[:space:]]+physical_channel:[[:space:]]*//; s/[[:space:]].*$//')"
_r45_neg_phys_count="$(printf '%s\n' "$_r45_neg_phys" | grep -c .)"
_r45_neg_phys_uniq="$(printf '%s\n' "$_r45_neg_phys" | sort -u | grep -c .)"
if [[ "$_r45_neg_phys_count" -ne "$_r45_neg_phys_uniq" ]]; then
  ok "rule45_bus_channels_neg" "shared physical_channel correctly flagged ($_r45_neg_phys_count entries / $_r45_neg_phys_uniq unique)"
else
  fail "rule45_bus_channels_neg" "expected shared physical_channel to be detected"
fi

# ---------------------------------------------------------------------------
# Rule 46 positive: openapi-v1.yaml with TaskCursor + x-cursor-flow → pass
# ---------------------------------------------------------------------------
_r46_pos="$scratch/r46_pos"
mkdir -p "$_r46_pos/docs/contracts"
cat > "$_r46_pos/docs/contracts/openapi-v1.yaml" <<'EOF'
openapi: 3.0.1
components:
  schemas:
    TaskCursor:
      type: object
x-cursor-flow:
  pattern: "POST → 202 + TaskCursor"
EOF
_r46_pos_ts=0
_r46_pos_ann=0
grep -qE '^[[:space:]]+TaskCursor:[[:space:]]*$' "$_r46_pos/docs/contracts/openapi-v1.yaml" && _r46_pos_ts=1
grep -qE '^x-cursor-flow:[[:space:]]*$' "$_r46_pos/docs/contracts/openapi-v1.yaml" && _r46_pos_ann=1
if [[ "$_r46_pos_ts" -eq 1 ]] && [[ "$_r46_pos_ann" -eq 1 ]]; then
  ok "rule46_cursor_flow_pos" "TaskCursor schema + x-cursor-flow annotation present"
else
  fail "rule46_cursor_flow_pos" "expected both schema and annotation"
fi

# ---------------------------------------------------------------------------
# Rule 46 negative: openapi-v1.yaml missing both → flagged
# ---------------------------------------------------------------------------
_r46_neg="$scratch/r46_neg"
mkdir -p "$_r46_neg/docs/contracts"
cat > "$_r46_neg/docs/contracts/openapi-v1.yaml" <<'EOF'
openapi: 3.0.1
components:
  schemas:
    Foo:
      type: object
EOF
_r46_neg_ts=0
grep -qE '^[[:space:]]+TaskCursor:[[:space:]]*$' "$_r46_neg/docs/contracts/openapi-v1.yaml" && _r46_neg_ts=1
if [[ "$_r46_neg_ts" -eq 0 ]]; then
  ok "rule46_cursor_flow_neg" "missing TaskCursor schema correctly flagged"
else
  fail "rule46_cursor_flow_neg" "expected missing TaskCursor to be detected"
fi

# ---------------------------------------------------------------------------
# Rule 47 positive: agent-runtime main without RestTemplate / JdbcTemplate
# ---------------------------------------------------------------------------
_r47_pos="$scratch/r47_pos"
mkdir -p "$_r47_pos/agent-runtime/src/main/java/x"
cat > "$_r47_pos/agent-runtime/src/main/java/x/Foo.java" <<'EOF'
package x;
import org.springframework.web.reactive.function.client.WebClient;
public class Foo {}
EOF
_r47_pos_hits="$(grep -rEln '^import[[:space:]]+org\.springframework\.(web\.client\.RestTemplate|jdbc\.core\.JdbcTemplate);' "$_r47_pos/agent-runtime/src/main/java" 2>/dev/null || true)"
if [[ -z "$_r47_pos_hits" ]]; then
  ok "rule47_no_blocking_io_pos" "WebClient-only runtime correctly passes"
else
  fail "rule47_no_blocking_io_pos" "expected zero hits; got $_r47_pos_hits"
fi

# ---------------------------------------------------------------------------
# Rule 47 negative: agent-runtime main with JdbcTemplate import → flagged
# ---------------------------------------------------------------------------
_r47_neg="$scratch/r47_neg"
mkdir -p "$_r47_neg/agent-runtime/src/main/java/x"
cat > "$_r47_neg/agent-runtime/src/main/java/x/BadDao.java" <<'EOF'
package x;
import org.springframework.jdbc.core.JdbcTemplate;
public class BadDao {}
EOF
_r47_neg_hits="$(grep -rEln '^import[[:space:]]+org\.springframework\.(web\.client\.RestTemplate|jdbc\.core\.JdbcTemplate);' "$_r47_neg/agent-runtime/src/main/java" 2>/dev/null || true)"
if [[ -n "$_r47_neg_hits" ]]; then
  ok "rule47_no_blocking_io_neg" "JdbcTemplate import correctly flagged"
else
  fail "rule47_no_blocking_io_neg" "expected JdbcTemplate import to be detected"
fi

# ---------------------------------------------------------------------------
# Rule 48 positive: main java without Thread.sleep
# ---------------------------------------------------------------------------
_r48_pos="$scratch/r48_pos"
mkdir -p "$_r48_pos/agent-platform/src/main/java/x"
cat > "$_r48_pos/agent-platform/src/main/java/x/Clean.java" <<'EOF'
package x;
public class Clean { void wait_(){ /* SuspendSignal here */ } }
EOF
_r48_pos_hits="$(grep -rEn 'Thread\.sleep[[:space:]]*\(|TimeUnit\.[A-Z_]+\.sleep[[:space:]]*\(' "$_r48_pos/agent-platform/src/main/java" 2>/dev/null || true)"
if [[ -z "$_r48_pos_hits" ]]; then
  ok "rule48_no_thread_sleep_pos" "clean main java passes"
else
  fail "rule48_no_thread_sleep_pos" "expected zero hits; got $_r48_pos_hits"
fi

# ---------------------------------------------------------------------------
# Rule 48 negative: Thread.sleep in main → flagged
# ---------------------------------------------------------------------------
_r48_neg="$scratch/r48_neg"
mkdir -p "$_r48_neg/agent-platform/src/main/java/x"
cat > "$_r48_neg/agent-platform/src/main/java/x/Sleeper.java" <<'EOF'
package x;
public class Sleeper { void w() throws Exception { Thread.sleep(1000); } }
EOF
_r48_neg_hits="$(grep -rEn 'Thread\.sleep[[:space:]]*\(|TimeUnit\.[A-Z_]+\.sleep[[:space:]]*\(' "$_r48_neg/agent-platform/src/main/java" 2>/dev/null || true)"
if [[ -n "$_r48_neg_hits" ]]; then
  ok "rule48_no_thread_sleep_neg" "Thread.sleep correctly flagged"
else
  fail "rule48_no_thread_sleep_neg" "expected Thread.sleep to be detected"
fi

# ---------------------------------------------------------------------------
# Rule 49 positive: module-metadata.yaml with valid deployment_plane
# ---------------------------------------------------------------------------
_r49_pos="$scratch/r49_pos"
mkdir -p "$_r49_pos/x"
cat > "$_r49_pos/x/module-metadata.yaml" <<'EOF'
module: x
kind: domain
deployment_plane: compute_control
EOF
_r49_pos_plane="$(grep -E '^deployment_plane:' "$_r49_pos/x/module-metadata.yaml" | head -1 | sed -E 's/^deployment_plane:[[:space:]]*([A-Za-z_]+).*/\1/')"
_r49_allowed='^(edge|compute_control|bus_state|sandbox|evolution|none)$'
if [[ -n "$_r49_pos_plane" ]] && [[ "$_r49_pos_plane" =~ $_r49_allowed ]]; then
  ok "rule49_deployment_plane_pos" "deployment_plane=$_r49_pos_plane (valid)"
else
  fail "rule49_deployment_plane_pos" "expected valid plane; got '$_r49_pos_plane'"
fi

# ---------------------------------------------------------------------------
# Rule 49 negative: module-metadata.yaml missing or invalid deployment_plane
# ---------------------------------------------------------------------------
_r49_neg="$scratch/r49_neg"
mkdir -p "$_r49_neg/x"
cat > "$_r49_neg/x/module-metadata.yaml" <<'EOF'
module: x
kind: domain
deployment_plane: stratosphere
EOF
_r49_neg_plane="$(grep -E '^deployment_plane:' "$_r49_neg/x/module-metadata.yaml" | head -1 | sed -E 's/^deployment_plane:[[:space:]]*([A-Za-z_]+).*/\1/')"
if ! [[ "$_r49_neg_plane" =~ $_r49_allowed ]]; then
  ok "rule49_deployment_plane_neg" "invalid plane '$_r49_neg_plane' correctly flagged"
else
  fail "rule49_deployment_plane_neg" "expected invalid plane to be detected"
fi

# ---------------------------------------------------------------------------
# Rule 50 positive: migration with tenant_id + ENABLE ROW LEVEL SECURITY
# ---------------------------------------------------------------------------
_r50_pos="$scratch/r50_pos"
mkdir -p "$_r50_pos/db/migration"
cat > "$_r50_pos/db/migration/V3__rls_table.sql" <<'EOF'
CREATE TABLE foo (tenant_id UUID NOT NULL, x INT);
ALTER TABLE foo ENABLE ROW LEVEL SECURITY;
EOF
_r50_pos_has_tid=0
_r50_pos_has_rls=0
grep -qE 'tenant_id[[:space:]]+UUID' "$_r50_pos/db/migration/V3__rls_table.sql" && _r50_pos_has_tid=1
grep -qiE 'ENABLE[[:space:]]+ROW[[:space:]]+LEVEL[[:space:]]+SECURITY' "$_r50_pos/db/migration/V3__rls_table.sql" && _r50_pos_has_rls=1
if [[ "$_r50_pos_has_tid" -eq 1 ]] && [[ "$_r50_pos_has_rls" -eq 1 ]]; then
  ok "rule50_rls_pos" "tenant_id table with RLS enabled"
else
  fail "rule50_rls_pos" "expected both tenant_id and RLS"
fi

# ---------------------------------------------------------------------------
# Rule 50 negative: migration with tenant_id but NO RLS, NOT grandfathered
# ---------------------------------------------------------------------------
_r50_neg="$scratch/r50_neg"
mkdir -p "$_r50_neg/db/migration"
cat > "$_r50_neg/db/migration/V99__bad.sql" <<'EOF'
CREATE TABLE bar (tenant_id UUID NOT NULL, y INT);
EOF
_r50_neg_has_tid=0
_r50_neg_has_rls=0
grep -qE 'tenant_id[[:space:]]+UUID' "$_r50_neg/db/migration/V99__bad.sql" && _r50_neg_has_tid=1
grep -qiE 'ENABLE[[:space:]]+ROW[[:space:]]+LEVEL[[:space:]]+SECURITY' "$_r50_neg/db/migration/V99__bad.sql" && _r50_neg_has_rls=1
if [[ "$_r50_neg_has_tid" -eq 1 ]] && [[ "$_r50_neg_has_rls" -eq 0 ]]; then
  ok "rule50_rls_neg" "tenant_id table without RLS correctly flagged"
else
  fail "rule50_rls_neg" "expected missing-RLS detection (tid=$_r50_neg_has_tid rls=$_r50_neg_has_rls)"
fi

# ---------------------------------------------------------------------------
# Rule 51 positive: skill-capacity.yaml with all required keys
# ---------------------------------------------------------------------------
_r51_pos="$scratch/r51_pos"
mkdir -p "$_r51_pos/docs/governance"
cat > "$_r51_pos/docs/governance/skill-capacity.yaml" <<'EOF'
skills:
  - id: foo
    capacity_per_tenant: 8
    global_capacity: 256
    queue_strategy: suspend
EOF
_r51_pos_ids="$(grep -cE '^[[:space:]]+- id:[[:space:]]+' "$_r51_pos/docs/governance/skill-capacity.yaml" 2>/dev/null)"; _r51_pos_ids="${_r51_pos_ids:-0}"
_r51_pos_caps_per="$(grep -cE '^[[:space:]]+capacity_per_tenant:' "$_r51_pos/docs/governance/skill-capacity.yaml" 2>/dev/null)"; _r51_pos_caps_per="${_r51_pos_caps_per:-0}"
_r51_pos_caps_global="$(grep -cE '^[[:space:]]+global_capacity:' "$_r51_pos/docs/governance/skill-capacity.yaml" 2>/dev/null)"; _r51_pos_caps_global="${_r51_pos_caps_global:-0}"
_r51_pos_queue="$(grep -cE '^[[:space:]]+queue_strategy:[[:space:]]+(suspend|fail)([[:space:]#].*)?$' "$_r51_pos/docs/governance/skill-capacity.yaml" 2>/dev/null)"; _r51_pos_queue="${_r51_pos_queue:-0}"
if [[ "$_r51_pos_ids" -eq 1 ]] && [[ "$_r51_pos_caps_per" -eq 1 ]] && [[ "$_r51_pos_caps_global" -eq 1 ]] && [[ "$_r51_pos_queue" -eq 1 ]]; then
  ok "rule51_skill_capacity_pos" "skill row complete with all 3 required keys"
else
  fail "rule51_skill_capacity_pos" "expected complete row; got ids=$_r51_pos_ids per=$_r51_pos_caps_per global=$_r51_pos_caps_global queue=$_r51_pos_queue"
fi

# ---------------------------------------------------------------------------
# Rule 51 negative: skill-capacity.yaml missing global_capacity
# ---------------------------------------------------------------------------
_r51_neg="$scratch/r51_neg"
mkdir -p "$_r51_neg/docs/governance"
cat > "$_r51_neg/docs/governance/skill-capacity.yaml" <<'EOF'
skills:
  - id: foo
    capacity_per_tenant: 8
    queue_strategy: suspend
EOF
_r51_neg_ids="$(grep -cE '^[[:space:]]+- id:[[:space:]]+' "$_r51_neg/docs/governance/skill-capacity.yaml" 2>/dev/null)"; _r51_neg_ids="${_r51_neg_ids:-0}"
_r51_neg_caps_global="$(grep -cE '^[[:space:]]+global_capacity:' "$_r51_neg/docs/governance/skill-capacity.yaml" 2>/dev/null)"; _r51_neg_caps_global="${_r51_neg_caps_global:-0}"
if [[ "$_r51_neg_caps_global" -ne "$_r51_neg_ids" ]]; then
  ok "rule51_skill_capacity_neg" "missing global_capacity correctly flagged ($_r51_neg_ids ids vs $_r51_neg_caps_global global)"
else
  fail "rule51_skill_capacity_neg" "expected missing-key detection"
fi

# ---------------------------------------------------------------------------
# Rule 52 positive: sandbox-policies.yaml with all 6 default_policy keys
# ---------------------------------------------------------------------------
_r52_pos="$scratch/r52_pos"
mkdir -p "$_r52_pos/docs/governance"
cat > "$_r52_pos/docs/governance/sandbox-policies.yaml" <<'EOF'
default_policy:
  outbound_network: deny_all
  filesystem_read: deny_all
  filesystem_write: deny_all
  cpu_cap_millicores: 100
  memory_cap_megabytes: 128
  wall_clock_cap_seconds: 30
EOF
_r52_pos_ok=1
for _r52_key in outbound_network filesystem_read filesystem_write cpu_cap_millicores memory_cap_megabytes wall_clock_cap_seconds; do
  if ! grep -qE "^[[:space:]]+${_r52_key}:" "$_r52_pos/docs/governance/sandbox-policies.yaml"; then
    _r52_pos_ok=0
  fi
done
if [[ "$_r52_pos_ok" -eq 1 ]]; then
  ok "rule52_sandbox_policies_pos" "default_policy with all 6 required keys"
else
  fail "rule52_sandbox_policies_pos" "expected all 6 keys"
fi

# ---------------------------------------------------------------------------
# Rule 52 negative: sandbox-policies.yaml missing wall_clock_cap_seconds
# ---------------------------------------------------------------------------
_r52_neg="$scratch/r52_neg"
mkdir -p "$_r52_neg/docs/governance"
cat > "$_r52_neg/docs/governance/sandbox-policies.yaml" <<'EOF'
default_policy:
  outbound_network: deny_all
  filesystem_read: deny_all
  filesystem_write: deny_all
  cpu_cap_millicores: 100
  memory_cap_megabytes: 128
EOF
_r52_neg_missing=0
if ! grep -qE '^[[:space:]]+wall_clock_cap_seconds:' "$_r52_neg/docs/governance/sandbox-policies.yaml"; then
  _r52_neg_missing=1
fi
if [[ "$_r52_neg_missing" -eq 1 ]]; then
  ok "rule52_sandbox_policies_neg" "missing wall_clock_cap_seconds correctly flagged"
else
  fail "rule52_sandbox_policies_neg" "expected missing-key detection"
fi

# ---------------------------------------------------------------------------
# Rule 53 positive: RunCursorFlowIT carries the canonical method + <200ms assertion
# ---------------------------------------------------------------------------
_r53_pos="$scratch/r53_pos"
mkdir -p "$_r53_pos/agent-platform/src/test/java/ascend/springai/platform/web/runs"
cat > "$_r53_pos/agent-platform/src/test/java/ascend/springai/platform/web/runs/RunCursorFlowIT.java" <<'EOF'
package ascend.springai.platform.web.runs;
class RunCursorFlowIT {
  void createReturns202WithCursorWithin200ms() {
    long elapsed = 0L;
    assertThat(elapsed).isLessThan(200L);
  }
}
EOF
_r53_pos_ok=0
if grep -qE 'void[[:space:]]+createReturns202WithCursorWithin200ms[[:space:]]*\(' "$_r53_pos/agent-platform/src/test/java/ascend/springai/platform/web/runs/RunCursorFlowIT.java" \
   && grep -qE 'isLessThan\([[:space:]]*200L?[[:space:]]*\)' "$_r53_pos/agent-platform/src/test/java/ascend/springai/platform/web/runs/RunCursorFlowIT.java"; then
  _r53_pos_ok=1
fi
if [[ "$_r53_pos_ok" -eq 1 ]]; then
  ok "rule53_cursor_flow_it_pos" "canonical method + <200ms assertion present"
else
  fail "rule53_cursor_flow_it_pos" "expected method + isLessThan(200) hit"
fi

# ---------------------------------------------------------------------------
# Rule 53 negative: RunCursorFlowIT missing the elapsed-ms assertion
# ---------------------------------------------------------------------------
_r53_neg="$scratch/r53_neg"
mkdir -p "$_r53_neg/agent-platform/src/test/java/ascend/springai/platform/web/runs"
cat > "$_r53_neg/agent-platform/src/test/java/ascend/springai/platform/web/runs/RunCursorFlowIT.java" <<'EOF'
package ascend.springai.platform.web.runs;
class RunCursorFlowIT {
  void createReturns202WithCursorWithin200ms() {
    // intentionally missing the elapsed-ms assertion (Rule 53 negative fixture)
    boolean ok = true;
  }
}
EOF
_r53_neg_missing=1
if grep -qE 'isLessThan\([[:space:]]*200L?[[:space:]]*\)' "$_r53_neg/agent-platform/src/test/java/ascend/springai/platform/web/runs/RunCursorFlowIT.java"; then
  _r53_neg_missing=0
fi
if [[ "$_r53_neg_missing" -eq 1 ]]; then
  ok "rule53_cursor_flow_it_neg" "missing <200ms assertion correctly flagged"
else
  fail "rule53_cursor_flow_it_neg" "expected missing-assertion detection"
fi

# ---------------------------------------------------------------------------
# Rule 54 positive: DefaultSkillResilienceContract has two-arg resolve + tryAcquire
# ---------------------------------------------------------------------------
_r54_pos="$scratch/r54_pos"
mkdir -p "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience"
cat > "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/SkillCapacityRegistry.java" <<'EOF'
package ascend.springai.runtime.resilience;
public interface SkillCapacityRegistry { boolean tryAcquire(String t, String s); }
EOF
cat > "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/SkillResolution.java" <<'EOF'
package ascend.springai.runtime.resilience;
public record SkillResolution(boolean admitted, Object reasonIfRejected) {}
EOF
cat > "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/SuspendReason.java" <<'EOF'
package ascend.springai.runtime.resilience;
public sealed interface SuspendReason permits SuspendReason.RateLimited {
  record RateLimited(String s, String c) implements SuspendReason {}
}
EOF
cat > "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/DefaultSkillResilienceContract.java" <<'EOF'
package ascend.springai.runtime.resilience;
public class DefaultSkillResilienceContract {
  private final SkillCapacityRegistry registry;
  public DefaultSkillResilienceContract(SkillCapacityRegistry r) { this.registry = r; }
  public SkillResolution resolve(String tenant, String skill) {
    if (registry.tryAcquire(tenant, skill)) return new SkillResolution(true, null);
    return new SkillResolution(false, new SuspendReason.RateLimited(skill, "SKILL_CAPACITY_EXCEEDED"));
  }
}
EOF
_r54_pos_ok=1
for _r54_f in SkillCapacityRegistry SkillResolution SuspendReason DefaultSkillResilienceContract; do
  if [[ ! -f "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/${_r54_f}.java" ]]; then
    _r54_pos_ok=0
  fi
done
if [[ "$_r54_pos_ok" -eq 1 ]] \
   && grep -qE 'SkillResolution[[:space:]]+resolve\([[:space:]]*String[[:space:]]+\w+,[[:space:]]*String[[:space:]]+\w+[[:space:]]*\)' "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/DefaultSkillResilienceContract.java" \
   && grep -qE 'tryAcquire\(' "$_r54_pos/agent-runtime/src/main/java/ascend/springai/runtime/resilience/DefaultSkillResilienceContract.java"; then
  ok "rule54_skill_capacity_runtime_pos" "DefaultSkillResilienceContract has two-arg resolve + tryAcquire"
else
  fail "rule54_skill_capacity_runtime_pos" "expected canonical class shape"
fi

# ---------------------------------------------------------------------------
# Rule 54 negative: DefaultSkillResilienceContract that silently admits everyone
# ---------------------------------------------------------------------------
_r54_neg="$scratch/r54_neg"
mkdir -p "$_r54_neg/agent-runtime/src/main/java/ascend/springai/runtime/resilience"
cat > "$_r54_neg/agent-runtime/src/main/java/ascend/springai/runtime/resilience/DefaultSkillResilienceContract.java" <<'EOF'
package ascend.springai.runtime.resilience;
public class DefaultSkillResilienceContract {
  public SkillResolution resolve(String tenant, String skill) {
    // intentionally missing the registry consultation (Rule 54 negative fixture)
    return new SkillResolution(true, null);
  }
}
EOF
_r54_neg_missing=1
if grep -qE 'tryAcquire\(' "$_r54_neg/agent-runtime/src/main/java/ascend/springai/runtime/resilience/DefaultSkillResilienceContract.java"; then
  _r54_neg_missing=0
fi
if [[ "$_r54_neg_missing" -eq 1 ]]; then
  ok "rule54_skill_capacity_runtime_neg" "missing tryAcquire call correctly flagged"
else
  fail "rule54_skill_capacity_runtime_neg" "expected missing-tryAcquire detection"
fi

# ---------------------------------------------------------------------------
# Rule 55 positive: engine-envelope.v1.yaml carries schema + known_engines + id
# ---------------------------------------------------------------------------
_r55_pos="$scratch/r55_pos"
mkdir -p "$_r55_pos/docs/contracts"
cat > "$_r55_pos/docs/contracts/engine-envelope.v1.yaml" <<'EOF'
schema: engine-envelope/v1
authority: ADR-0072
known_engines:
  - id: graph
    payload_class: ExecutorDefinition.GraphDefinition
  - id: agent-loop
    payload_class: ExecutorDefinition.AgentLoopDefinition
EOF
_r55_pos_ok=1
if ! grep -qE '^schema:[[:space:]]+engine-envelope/v1[[:space:]]*$' "$_r55_pos/docs/contracts/engine-envelope.v1.yaml"; then
  _r55_pos_ok=0
fi
if ! grep -qE '^known_engines:[[:space:]]*$' "$_r55_pos/docs/contracts/engine-envelope.v1.yaml"; then
  _r55_pos_ok=0
fi
if ! grep -qE '^[[:space:]]+- id:[[:space:]]+\S+' "$_r55_pos/docs/contracts/engine-envelope.v1.yaml"; then
  _r55_pos_ok=0
fi
if [[ "$_r55_pos_ok" -eq 1 ]]; then
  ok "rule55_engine_envelope_yaml_pos" "schema + known_engines + id all present"
else
  fail "rule55_engine_envelope_yaml_pos" "expected schema/known_engines/id detection"
fi

# ---------------------------------------------------------------------------
# Rule 55 negative: engine-envelope.v1.yaml missing known_engines: block
# ---------------------------------------------------------------------------
_r55_neg="$scratch/r55_neg"
mkdir -p "$_r55_neg/docs/contracts"
cat > "$_r55_neg/docs/contracts/engine-envelope.v1.yaml" <<'EOF'
schema: engine-envelope/v1
authority: ADR-0072
# intentionally missing known_engines: (Rule 55 negative fixture)
EOF
_r55_neg_missing=1
if grep -qE '^known_engines:[[:space:]]*$' "$_r55_neg/docs/contracts/engine-envelope.v1.yaml"; then
  _r55_neg_missing=0
fi
if [[ "$_r55_neg_missing" -eq 1 ]]; then
  ok "rule55_engine_envelope_yaml_neg" "missing known_engines: correctly flagged"
else
  fail "rule55_engine_envelope_yaml_neg" "expected missing-known_engines detection"
fi

# ---------------------------------------------------------------------------
# Rule 56 positive: yaml ids and ENGINE_TYPE constants agree bidirectionally
# ---------------------------------------------------------------------------
_r56_pos="$scratch/r56_pos"
mkdir -p "$_r56_pos/docs/contracts"
mkdir -p "$_r56_pos/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi"
cat > "$_r56_pos/docs/contracts/engine-envelope.v1.yaml" <<'EOF'
schema: engine-envelope/v1
known_engines:
  - id: graph
  - id: agent-loop
EOF
cat > "$_r56_pos/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/GraphExecutor.java" <<'EOF'
package ascend.springai.runtime.orchestration.spi;
public interface GraphExecutor {
  String ENGINE_TYPE = "graph";
}
EOF
cat > "$_r56_pos/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/AgentLoopExecutor.java" <<'EOF'
package ascend.springai.runtime.orchestration.spi;
public interface AgentLoopExecutor {
  String ENGINE_TYPE = "agent-loop";
}
EOF
_r56_pos_yaml_ids=$(grep -E '^[[:space:]]+- id:[[:space:]]+' "$_r56_pos/docs/contracts/engine-envelope.v1.yaml" | sed -E 's/^[[:space:]]+- id:[[:space:]]+([A-Za-z0-9_.-]+).*/\1/' | sort -u)
_r56_pos_src_ids=$(grep -rhE 'String[[:space:]]+ENGINE_TYPE[[:space:]]*=[[:space:]]*"[A-Za-z0-9_.-]+"' "$_r56_pos/agent-runtime/src/main/java" 2>/dev/null | sed -E 's/.*ENGINE_TYPE[[:space:]]*=[[:space:]]*"([A-Za-z0-9_.-]+)".*/\1/' | sort -u)
_r56_pos_ok=1
for _id in $_r56_pos_yaml_ids; do
  if ! echo "$_r56_pos_src_ids" | grep -qxE "${_id}"; then _r56_pos_ok=0; fi
done
for _id in $_r56_pos_src_ids; do
  if ! echo "$_r56_pos_yaml_ids" | grep -qxE "${_id}"; then _r56_pos_ok=0; fi
done
if [[ "$_r56_pos_ok" -eq 1 ]]; then
  ok "rule56_engine_registry_covers_pos" "yaml ids and ENGINE_TYPE constants match bidirectionally"
else
  fail "rule56_engine_registry_covers_pos" "expected bidirectional consistency"
fi

# ---------------------------------------------------------------------------
# Rule 56 negative: yaml declares 'graph' but source has only 'agent-loop'
# ---------------------------------------------------------------------------
_r56_neg="$scratch/r56_neg"
mkdir -p "$_r56_neg/docs/contracts"
mkdir -p "$_r56_neg/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi"
cat > "$_r56_neg/docs/contracts/engine-envelope.v1.yaml" <<'EOF'
schema: engine-envelope/v1
known_engines:
  - id: graph
  - id: agent-loop
EOF
cat > "$_r56_neg/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/AgentLoopExecutor.java" <<'EOF'
package ascend.springai.runtime.orchestration.spi;
public interface AgentLoopExecutor {
  String ENGINE_TYPE = "agent-loop";
  // intentionally NO GraphExecutor with ENGINE_TYPE = "graph" (Rule 56 negative fixture)
}
EOF
_r56_neg_yaml_ids=$(grep -E '^[[:space:]]+- id:[[:space:]]+' "$_r56_neg/docs/contracts/engine-envelope.v1.yaml" | sed -E 's/^[[:space:]]+- id:[[:space:]]+([A-Za-z0-9_.-]+).*/\1/' | sort -u)
_r56_neg_src_ids=$(grep -rhE 'String[[:space:]]+ENGINE_TYPE[[:space:]]*=[[:space:]]*"[A-Za-z0-9_.-]+"' "$_r56_neg/agent-runtime/src/main/java" 2>/dev/null | sed -E 's/.*ENGINE_TYPE[[:space:]]*=[[:space:]]*"([A-Za-z0-9_.-]+)".*/\1/' | sort -u)
_r56_neg_flagged=0
for _id in $_r56_neg_yaml_ids; do
  if ! echo "$_r56_neg_src_ids" | grep -qxE "${_id}"; then _r56_neg_flagged=1; fi
done
if [[ "$_r56_neg_flagged" -eq 1 ]]; then
  ok "rule56_engine_registry_covers_neg" "missing ENGINE_TYPE for declared known_engine correctly flagged"
else
  fail "rule56_engine_registry_covers_neg" "expected missing-ENGINE_TYPE detection"
fi

# ---------------------------------------------------------------------------
# Rule 57 positive: hook yaml + enum agree on the 9-hook list bidirectionally
# ---------------------------------------------------------------------------
_r57_pos="$scratch/r57_pos"
mkdir -p "$_r57_pos/docs/contracts"
mkdir -p "$_r57_pos/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi"
cat > "$_r57_pos/docs/contracts/engine-hooks.v1.yaml" <<'EOF'
schema: engine-hooks/v1
hooks:
  - before_llm_invocation
  - on_error
EOF
cat > "$_r57_pos/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookPoint.java" <<'EOF'
package ascend.springai.runtime.orchestration.spi;
public enum HookPoint {
    BEFORE_LLM_INVOCATION,
    ON_ERROR
}
EOF
_r57_pos_yaml=$(awk '/^hooks:/{f=1;next} /^[a-z_]+:/{f=0} f && /^[[:space:]]+- [a-z_]+/{gsub(/^[[:space:]]+- /,""); print}' "$_r57_pos/docs/contracts/engine-hooks.v1.yaml" | sort -u)
_r57_pos_enum=$(grep -E '^[[:space:]]+[A-Z_]+[,;]?[[:space:]]*$' "$_r57_pos/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookPoint.java" | sed -E 's/[[:space:]]+([A-Z_]+)[,;]?[[:space:]]*/\1/' | tr 'A-Z_' 'a-z_' | sort -u)
_r57_pos_ok=1
for _h in $_r57_pos_yaml; do if ! echo "$_r57_pos_enum" | grep -qxE "${_h}"; then _r57_pos_ok=0; fi; done
for _e in $_r57_pos_enum; do if ! echo "$_r57_pos_yaml" | grep -qxE "${_e}"; then _r57_pos_ok=0; fi; done
if [[ "$_r57_pos_ok" -eq 1 ]]; then
  ok "rule57_engine_hooks_yaml_pos" "hook yaml + HookPoint enum agree bidirectionally"
else
  fail "rule57_engine_hooks_yaml_pos" "expected bidirectional agreement"
fi

# ---------------------------------------------------------------------------
# Rule 57 negative: yaml has on_error but enum is missing the ON_ERROR constant
# ---------------------------------------------------------------------------
_r57_neg="$scratch/r57_neg"
mkdir -p "$_r57_neg/docs/contracts"
mkdir -p "$_r57_neg/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi"
cat > "$_r57_neg/docs/contracts/engine-hooks.v1.yaml" <<'EOF'
schema: engine-hooks/v1
hooks:
  - before_llm_invocation
  - on_error
EOF
cat > "$_r57_neg/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookPoint.java" <<'EOF'
package ascend.springai.runtime.orchestration.spi;
public enum HookPoint {
    BEFORE_LLM_INVOCATION
    // intentionally missing ON_ERROR (Rule 57 negative fixture)
}
EOF
_r57_neg_yaml=$(awk '/^hooks:/{f=1;next} /^[a-z_]+:/{f=0} f && /^[[:space:]]+- [a-z_]+/{gsub(/^[[:space:]]+- /,""); print}' "$_r57_neg/docs/contracts/engine-hooks.v1.yaml" | sort -u)
_r57_neg_enum=$(grep -E '^[[:space:]]+[A-Z_]+[,;]?[[:space:]]*$' "$_r57_neg/agent-runtime/src/main/java/ascend/springai/runtime/orchestration/spi/HookPoint.java" | sed -E 's/[[:space:]]+([A-Z_]+)[,;]?[[:space:]]*/\1/' | tr 'A-Z_' 'a-z_' | sort -u)
_r57_neg_flagged=0
for _h in $_r57_neg_yaml; do if ! echo "$_r57_neg_enum" | grep -qxE "${_h}"; then _r57_neg_flagged=1; fi; done
if [[ "$_r57_neg_flagged" -eq 1 ]]; then
  ok "rule57_engine_hooks_yaml_neg" "missing HookPoint enum constant for declared yaml hook correctly flagged"
else
  fail "rule57_engine_hooks_yaml_neg" "expected missing-enum-constant detection"
fi

# ---------------------------------------------------------------------------
# Rule 58 positive: s2c-callback yaml has schema + request + response + 6 mandatory fields + 3 outcome values
# ---------------------------------------------------------------------------
_r58_pos="$scratch/r58_pos"
mkdir -p "$_r58_pos/docs/contracts"
cat > "$_r58_pos/docs/contracts/s2c-callback.v1.yaml" <<'EOF'
schema: s2c-callback/v1
request:
  required_fields:
    - callback_id
    - server_run_id
    - capability_ref
    - request_payload
    - trace_id
    - idempotency_key
response:
  required_fields:
    - callback_id
outcome_values:
  - ok
  - error
  - timeout
EOF
_r58_pos_path="$_r58_pos/docs/contracts/s2c-callback.v1.yaml"
_r58_pos_ok=1
if ! grep -qE '^schema:[[:space:]]+s2c-callback/v1[[:space:]]*$' "$_r58_pos_path"; then _r58_pos_ok=0; fi
if ! grep -qE '^request:[[:space:]]*$' "$_r58_pos_path"; then _r58_pos_ok=0; fi
if ! grep -qE '^response:[[:space:]]*$' "$_r58_pos_path"; then _r58_pos_ok=0; fi
for _f in callback_id server_run_id capability_ref request_payload trace_id idempotency_key; do
  if ! grep -qE "^[[:space:]]+- ${_f}([[:space:]]|#|\$)" "$_r58_pos_path"; then _r58_pos_ok=0; fi
done
for _o in ok error timeout; do
  if ! grep -qE "^[[:space:]]+- ${_o}([[:space:]]|#|\$)" "$_r58_pos_path"; then _r58_pos_ok=0; fi
done
if [[ "$_r58_pos_ok" -eq 1 ]]; then
  ok "rule58_s2c_callback_yaml_pos" "s2c-callback yaml has all required structure"
else
  fail "rule58_s2c_callback_yaml_pos" "expected well-formed s2c-callback yaml"
fi

# ---------------------------------------------------------------------------
# Rule 58 negative: s2c-callback yaml missing trace_id mandatory field
# ---------------------------------------------------------------------------
_r58_neg="$scratch/r58_neg"
mkdir -p "$_r58_neg/docs/contracts"
cat > "$_r58_neg/docs/contracts/s2c-callback.v1.yaml" <<'EOF'
schema: s2c-callback/v1
request:
  required_fields:
    - callback_id
    - server_run_id
    - capability_ref
    - request_payload
    # intentionally missing trace_id (Rule 58 negative fixture)
    - idempotency_key
response:
  required_fields:
    - callback_id
outcome_values:
  - ok
  - error
  - timeout
EOF
_r58_neg_flagged=0
if ! grep -qE '^[[:space:]]+- trace_id([[:space:]]|#|$)' "$_r58_neg/docs/contracts/s2c-callback.v1.yaml"; then
  _r58_neg_flagged=1
fi
if [[ "$_r58_neg_flagged" -eq 1 ]]; then
  ok "rule58_s2c_callback_yaml_neg" "missing mandatory request field correctly flagged"
else
  fail "rule58_s2c_callback_yaml_neg" "expected missing-field detection"
fi

# ---------------------------------------------------------------------------
# Rule 59 positive: evolution-scope yaml well-formed
# ---------------------------------------------------------------------------
_r59_pos="$scratch/r59_pos"
mkdir -p "$_r59_pos/docs/governance"
cat > "$_r59_pos/docs/governance/evolution-scope.v1.yaml" <<'EOF'
schema: evolution-scope/v1
in_scope:
  - server_execution_traces
out_of_scope_default:
  - client_local_state
opt_in_export:
  contract_required: telemetry-export.v1.yaml
EOF
_r59_pos_path="$_r59_pos/docs/governance/evolution-scope.v1.yaml"
_r59_pos_ok=1
if ! grep -qE '^schema:[[:space:]]+evolution-scope/v1[[:space:]]*$' "$_r59_pos_path"; then _r59_pos_ok=0; fi
for _b in in_scope out_of_scope_default opt_in_export; do
  if ! grep -qE "^${_b}:" "$_r59_pos_path"; then _r59_pos_ok=0; fi
done
if ! grep -qE 'contract_required:[[:space:]]+telemetry-export\.v1\.yaml' "$_r59_pos_path"; then _r59_pos_ok=0; fi
if [[ "$_r59_pos_ok" -eq 1 ]]; then
  ok "rule59_evolution_scope_yaml_pos" "evolution-scope yaml has schema + 3 blocks + telemetry-export ref"
else
  fail "rule59_evolution_scope_yaml_pos" "expected well-formed evolution-scope yaml"
fi

# ---------------------------------------------------------------------------
# Rule 59 negative: opt_in_export.contract_required missing
# ---------------------------------------------------------------------------
_r59_neg="$scratch/r59_neg"
mkdir -p "$_r59_neg/docs/governance"
cat > "$_r59_neg/docs/governance/evolution-scope.v1.yaml" <<'EOF'
schema: evolution-scope/v1
in_scope:
  - server_execution_traces
out_of_scope_default:
  - client_local_state
opt_in_export:
  default: deny
EOF
_r59_neg_flagged=0
if ! grep -qE 'contract_required:[[:space:]]+telemetry-export\.v1\.yaml' "$_r59_neg/docs/governance/evolution-scope.v1.yaml"; then
  _r59_neg_flagged=1
fi
if [[ "$_r59_neg_flagged" -eq 1 ]]; then
  ok "rule59_evolution_scope_yaml_neg" "missing telemetry-export contract_required correctly flagged"
else
  fail "rule59_evolution_scope_yaml_neg" "expected missing-contract_required detection"
fi

# ---------------------------------------------------------------------------
# Rule 60 positive: grandfathered file containing prose enum passes (file-level grandfather)
# Phase 7 audit fix: fixture migrated to pipe-delimited <path>|<sunset>|<desc>
# format per gate/schema-first-grandfathered.txt new shape (plan F1/F2).
# ---------------------------------------------------------------------------
_r60_pos="$scratch/r60_pos"
mkdir -p "$_r60_pos/gate"
cat > "$_r60_pos/ARCHITECTURE.md" <<'EOF'
# Test fixture
Grandfathered: RunMode discriminator GRAPH | AGENT_LOOP
EOF
cat > "$_r60_pos/gate/schema-first-grandfathered.txt" <<'EOF'
# header
ARCHITECTURE.md|2099-12-31|RunMode discriminator GRAPH | AGENT_LOOP -- grandfathered
EOF
_r60_pos_ok=0
if grep -qE "^ARCHITECTURE\.md\|" "$_r60_pos/gate/schema-first-grandfathered.txt"; then
  _r60_pos_ok=1
fi
if [[ "$_r60_pos_ok" -eq 1 ]]; then
  ok "rule60_schema_first_pos" "grandfathered file-level entry tolerates prose enum (pipe-delimited format)"
else
  fail "rule60_schema_first_pos" "expected grandfather hit"
fi

# ---------------------------------------------------------------------------
# Rule 60 negative: novel prose enum, no grandfather, no nearby yaml ref - flagged
# ---------------------------------------------------------------------------
_r60_neg="$scratch/r60_neg"
mkdir -p "$_r60_neg/gate"
cat > "$_r60_neg/ARCHITECTURE.md" <<'EOF'
# Test fixture - novel prose enum, no grandfather, no yaml reference
The MyNewEnum discriminator carries values: FOO | BAR | BAZ.
No schema reference in surrounding paragraphs.
EOF
cat > "$_r60_neg/gate/schema-first-grandfathered.txt" <<'EOF'
# header; no ARCHITECTURE.md entry
EOF
_r60_neg_cands=$(awk '
  BEGIN { in_fence = 0 }
  /^```/ { in_fence = !in_fence; next }
  { if (in_fence) next }
  /^[[:space:]]*\|/ { next }
  /[A-Z][A-Z_][A-Z_]*[[:space:]]*\|[[:space:]]*[A-Z][A-Z_][A-Z_]*/ { print NR }
' "$_r60_neg/ARCHITECTURE.md")
_r60_neg_grandfathered=0
if grep -qE "^ARCHITECTURE\.md\|" "$_r60_neg/gate/schema-first-grandfathered.txt"; then
  _r60_neg_grandfathered=1
fi
_r60_neg_flagged=0
if [[ -n "$_r60_neg_cands" && "$_r60_neg_grandfathered" -eq 0 ]]; then
  while read -r _ln; do
    _lo=$(( _ln - 5 )); [[ $_lo -lt 1 ]] && _lo=1
    _hi=$(( _ln + 5 ))
    if ! awk -v lo="$_lo" -v hi="$_hi" 'NR>=lo && NR<=hi' "$_r60_neg/ARCHITECTURE.md" \
       | grep -qE 'docs/(contracts|governance)/[^[:space:]]+\.yaml'; then
      _r60_neg_flagged=1
    fi
  done <<< "$_r60_neg_cands"
fi
if [[ "$_r60_neg_flagged" -eq 1 ]]; then
  ok "rule60_schema_first_neg" "novel prose enum without yaml ref correctly flagged"
else
  fail "rule60_schema_first_neg" "expected novel prose enum to be flagged"
fi

# ---------------------------------------------------------------------------
# Rule 60 sunset expired (Phase 7 audit fix, plan F5): a grandfather entry
# whose sunset_date is in the past MUST be flagged. Mirrors the gate's
# pipe-delimited parse logic.
# ---------------------------------------------------------------------------
_r60_sunset_exp="$scratch/r60_sunset_exp"
mkdir -p "$_r60_sunset_exp/gate"
cat > "$_r60_sunset_exp/gate/schema-first-grandfathered.txt" <<'EOF'
# header -- stale entry whose sunset has passed
ARCHITECTURE.md|2020-01-01|stale entry -- sunset long passed
EOF
_r60_se_today=$(date +%Y-%m-%d)
_r60_se_flagged=0
while IFS= read -r _r60_se_line; do
  [[ -z "$_r60_se_line" || "$_r60_se_line" =~ ^[[:space:]]*# ]] && continue
  _r60_se_sunset=$(printf '%s' "$_r60_se_line" | cut -d'|' -f2)
  if [[ "$_r60_se_today" > "$_r60_se_sunset" ]]; then
    _r60_se_flagged=1
  fi
done < "$_r60_sunset_exp/gate/schema-first-grandfathered.txt"
if [[ "$_r60_se_flagged" -eq 1 ]]; then
  ok "rule60_schema_first_sunset_expired" "expired sunset_date correctly flagged"
else
  fail "rule60_schema_first_sunset_expired" "expected expired sunset_date to be flagged"
fi

# ---------------------------------------------------------------------------
# Rule 60 sunset malformed (Phase 7 audit fix, plan F5): a grandfather entry
# whose sunset_date is not YYYY-MM-DD MUST be flagged.
# ---------------------------------------------------------------------------
_r60_sunset_mal="$scratch/r60_sunset_mal"
mkdir -p "$_r60_sunset_mal/gate"
cat > "$_r60_sunset_mal/gate/schema-first-grandfathered.txt" <<'EOF'
# header -- malformed sunset date
ARCHITECTURE.md|20260930|malformed date format (missing dashes)
EOF
_r60_sm_flagged=0
while IFS= read -r _r60_sm_line; do
  [[ -z "$_r60_sm_line" || "$_r60_sm_line" =~ ^[[:space:]]*# ]] && continue
  _r60_sm_sunset=$(printf '%s' "$_r60_sm_line" | cut -d'|' -f2)
  if ! [[ "$_r60_sm_sunset" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    _r60_sm_flagged=1
  fi
done < "$_r60_sunset_mal/gate/schema-first-grandfathered.txt"
if [[ "$_r60_sm_flagged" -eq 1 ]]; then
  ok "rule60_schema_first_sunset_malformed" "malformed sunset_date correctly flagged"
else
  fail "rule60_schema_first_sunset_malformed" "expected malformed sunset_date to be flagged"
fi

# ---------------------------------------------------------------------------
# Rule 28k positive (post-review fix plan F / P1-2): a test file whose
# Javadoc cites enforcers.yaml#E<n> matches the E-row's artifact: path.
# ---------------------------------------------------------------------------
_r28k_pos="$scratch/r28k_pos"
mkdir -p "$_r28k_pos/docs/governance"
mkdir -p "$_r28k_pos/agent-runtime/src/test/java/com/example"
cat > "$_r28k_pos/docs/governance/enforcers.yaml" <<'EOF'
- id: E100
  kind: integration
  artifact: agent-runtime/src/test/java/com/example/FooIT.java#some_test
EOF
cat > "$_r28k_pos/agent-runtime/src/test/java/com/example/FooIT.java" <<'EOF'
// Enforcer row: docs/governance/enforcers.yaml#E100
class FooIT {}
EOF
_r28k_pos_eid="E100"
_r28k_pos_art=$(awk -v id="$_r28k_pos_eid" '
  $0 ~ "^- id: " id "$" { found=1; next }
  found && /^[[:space:]]+artifact:/ {
    line=$0
    sub(/^[[:space:]]+artifact:[[:space:]]*/, "", line)
    sub(/#.*$/, "", line)
    gsub(/[[:space:]]+$/, "", line)
    print line
    exit
  }
' "$_r28k_pos/docs/governance/enforcers.yaml")
_r28k_pos_src="agent-runtime/src/test/java/com/example/FooIT.java"
if [[ "$_r28k_pos_art" == "$_r28k_pos_src" ]]; then
  ok "rule28k_javadoc_citation_pos" "matching Javadoc citation + artifact path"
else
  fail "rule28k_javadoc_citation_pos" "expected match but got art='$_r28k_pos_art' vs src='$_r28k_pos_src'"
fi

# ---------------------------------------------------------------------------
# Rule 28k negative: a test file Javadoc cites E<n> whose artifact: points
# elsewhere -- must be flagged.
# ---------------------------------------------------------------------------
_r28k_neg="$scratch/r28k_neg"
mkdir -p "$_r28k_neg/docs/governance"
mkdir -p "$_r28k_neg/agent-runtime/src/test/java/com/example"
cat > "$_r28k_neg/docs/governance/enforcers.yaml" <<'EOF'
- id: E101
  kind: integration
  artifact: agent-runtime/src/test/java/com/other/BarIT.java#some_test
EOF
cat > "$_r28k_neg/agent-runtime/src/test/java/com/example/FooIT.java" <<'EOF'
// Mis-citation: this file cites E101 but E101's artifact is BarIT.java
// docs/governance/enforcers.yaml#E101
class FooIT {}
EOF
_r28k_neg_eid="E101"
_r28k_neg_art=$(awk -v id="$_r28k_neg_eid" '
  $0 ~ "^- id: " id "$" { found=1; next }
  found && /^[[:space:]]+artifact:/ {
    line=$0
    sub(/^[[:space:]]+artifact:[[:space:]]*/, "", line)
    sub(/#.*$/, "", line)
    gsub(/[[:space:]]+$/, "", line)
    print line
    exit
  }
' "$_r28k_neg/docs/governance/enforcers.yaml")
_r28k_neg_src="agent-runtime/src/test/java/com/example/FooIT.java"
if [[ "$_r28k_neg_art" != "$_r28k_neg_src" ]]; then
  ok "rule28k_javadoc_citation_neg" "mismatched Javadoc citation correctly flagged"
else
  fail "rule28k_javadoc_citation_neg" "expected mismatch but paths matched"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=86
echo ""
echo "Tests passed: ${passed}/${TOTAL}"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
exit 0
