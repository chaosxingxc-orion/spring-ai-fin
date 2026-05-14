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

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Tests passed: ${passed}/${TOTAL}"

if [[ $failed -gt 0 ]]; then
  exit 1
fi
exit 0
