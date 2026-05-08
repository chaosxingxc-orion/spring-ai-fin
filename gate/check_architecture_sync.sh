#!/usr/bin/env bash
# spring-ai-fin architecture-sync gate (cycle-5 expanded; POSIX bash).
# Catches drift classes from cycles 1-5.
#
# Cycle-5 changes:
#   - Platform-suffix log filenames: gate/log/<sha>-posix.json (delivery-valid)
#     or gate/log/local/<sha>-posix.json (non-delivery). Preserves
#     cross-platform evidence when both POSIX and PowerShell scripts run
#     against the same SHA.
#   - rls_reset_vocabulary scope expanded to all L0/L1/L2 ARCHITECTURE.md
#     files (was only governance/diagram/matrix).
#   - New hs256_prod_conflict rule: docs/security-control-matrix.md must not
#     mention HS256 and "prod" on the same control row unless the row
#     explicitly says "rejected" or "not permitted".
#
# Architecture-sync gate, NOT Rule 8 operator-shape gate.

set -euo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

local_only=0
for arg in "$@"; do
  case "$arg" in
    --local-only) local_only=1 ;;
    -h|--help)
      cat <<EOF
Usage: $0 [--local-only]

Default mode fails when 'git status --porcelain' is non-empty.
--local-only mode permits dirty tree; in any non-delivery-valid case
the log is written to gate/log/local/<sha>-posix.json (gitignored), not
gate/log/<sha>-posix.json.
EOF
      exit 0
      ;;
  esac
done

failures_json=""
fail_count=0
dirty_tree_count=0

json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

fail() {
  local category="$1"
  local message="$2"
  local path="$3"
  local line="${4:-0}"
  if [[ -n "$failures_json" ]]; then failures_json+=","; fi
  failures_json+="{\"category\":\"$(json_escape "$category")\",\"message\":\"$(json_escape "$message")\",\"path\":\"$(json_escape "$path")\",\"line\":${line}}"
  fail_count=$((fail_count + 1))
  if [[ "$category" == "dirty_tree" ]]; then dirty_tree_count=$((dirty_tree_count + 1)); fi
}

# 0. Working tree.
porcelain="$(git status --porcelain 2>/dev/null || true)"
tree_clean=true
[[ -n "$porcelain" ]] && tree_clean=false

if [[ "$tree_clean" == "false" && "$local_only" -eq 0 ]]; then
  fail "dirty_tree" "working tree is dirty; pass --local-only for non-delivery evidence" "" 0
fi

# Build scan lists.
declare -a all_scan_files=()
declare -a non_docs_arch_files=()
declare -a platform_arch_files=()

[[ -f ARCHITECTURE.md ]] && { all_scan_files+=("ARCHITECTURE.md"); non_docs_arch_files+=("ARCHITECTURE.md"); }

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  all_scan_files+=("$f")
  non_docs_arch_files+=("$f")
done < <(find agent-platform agent-runtime -type f -name 'ARCHITECTURE.md' 2>/dev/null || true)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  platform_arch_files+=("$f")
done < <(find agent-platform -type f -name 'ARCHITECTURE.md' 2>/dev/null || true)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *systematic-architecture-improvement-plan*) continue ;;
    *systematic-architecture-remediation-plan*) continue ;;
    *closure-taxonomy.md*) continue ;;
    *security-response-2026-05-08*) continue ;;
    *architecture-v5.0*) continue ;;
    *architecture-review-2026-05-07*) continue ;;
    *deep-architecture-security-assessment*) continue ;;
  esac
  all_scan_files+=("$f")
done < <(find docs -type f -name '*.md' 2>/dev/null || true)

for f in "${all_scan_files[@]}"; do
  if [[ ! -e "$f" ]]; then
    fail "gate_self_test_failed" "scan list contains non-existent path: $f" "" 0
  fi
done

# 1. Forbidden closure shortcuts: substring patterns.
forbidden_substrings=(
  "production-ready pending implementation"
  "operator-gated by intention"
  "verified by review only"
)
for f in "${all_scan_files[@]}"; do
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    for phrase in "${forbidden_substrings[@]}"; do
      if [[ "$line" == *"$phrase"* ]]; then
        fail "forbidden_closure_shortcut" "matched '$phrase'" "$f" "$lineno"
      fi
    done
  done < "$f"
done

# 1b. Forbidden closure shortcuts: case-insensitive regex.
declare -a closure_regex_names=(
  "closes_pn_phrase"
  "pn_closure_phrase"
  "closure_rests_on_phrase"
  "closed_by_design_phrase"
  "fixed_in_docs_phrase"
  "accepted_therefore_closed_phrase"
)
declare -a closure_regex_patterns=(
  '\bcloses?\s+(security\s+review\s+)?(§)?P[0-9]+-[0-9]+\b'
  '\bP[0-9]+-[0-9]+\s+closure\b'
  '\bclosure\s+rests\s+on\b'
  '\bclosed\s+by\s+design\b'
  '\bfixed\s+in\s+docs\b'
  '\baccepted,\s*therefore\s*closed\b'
)
for f in "${all_scan_files[@]}"; do
  for idx in "${!closure_regex_patterns[@]}"; do
    name="${closure_regex_names[$idx]}"
    pat="${closure_regex_patterns[$idx]}"
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      lineno="${m%%:*}"
      fail "forbidden_closure_shortcut" "matched '$name'" "$f" "$lineno"
    done < <(grep -niP "$pat" "$f" 2>/dev/null || true)
  done
done

# 2. Saga overpromised consistency.
saga_phrases=(
  "strong within saga"
  "cross-entity strong consistency"
  "all-or-nothing across step failure points"
)
for f in "${non_docs_arch_files[@]}"; do
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    for phrase in "${saga_phrases[@]}"; do
      if [[ "$line" == *"$phrase"* ]]; then
        fail "saga_overpromised_consistency" "matched '$phrase'" "$f" "$lineno"
      fi
    done
  done < "$f"
done

# 3. ActionGuard stage drift.
ten_stage_patterns=("10-stage" "10 stages" "ten-stage" "ten stages")
for f in "${all_scan_files[@]}"; do
  declare -a buf=()
  while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$f"
  n=${#buf[@]}
  for ((i=0; i<n; i++)); do
    line="${buf[i]}"
    for pat in "${ten_stage_patterns[@]}"; do
      if [[ "$line" == *"$pat"* ]]; then
        ag=0
        [[ "$line" == *ActionGuard* ]] && ag=1
        if [[ $ag -eq 0 && $i -gt 0 ]]; then
          [[ "${buf[i-1]}" == *ActionGuard* ]] && ag=1
        fi
        if [[ $ag -eq 0 && $((i+1)) -lt $n ]]; then
          [[ "${buf[i+1]}" == *ActionGuard* ]] && ag=1
        fi
        if [[ $ag -eq 1 ]]; then
          fail "actionguard_stage_drift" "matched '$pat' near 'ActionGuard'" "$f" "$((i+1))"
        fi
      fi
    done
  done
  unset buf
done

# 4. Pre/Post evidence stages in action-guard L2.
ag_l2="agent-runtime/action-guard/ARCHITECTURE.md"
if [[ -f "$ag_l2" ]]; then
  if ! grep -F -q "PreActionEvidenceWriter" "$ag_l2"; then
    fail "actionguard_pre_post_evidence_missing" "action-guard L2 does not mention 'PreActionEvidenceWriter'" "$ag_l2" 0
  fi
  if ! grep -F -q "PostActionEvidenceWriter" "$ag_l2"; then
    fail "actionguard_pre_post_evidence_missing" "action-guard L2 does not mention 'PostActionEvidenceWriter'" "$ag_l2" 0
  fi
fi

# 5. Contract posture purity (all platform L2s).
bad_posture_patterns=(
  'contracts read .* `Environment\.getProperty'
  'contracts read posture from .Environment'
  'Posture in .Environment\.getProperty. for contracts'
  'contracts/.* package reads .APP_POSTURE'
  'contracts read .* via .Environment'
  'mirror via .Environment\.getProperty'
)
for f in "${platform_arch_files[@]}"; do
  for pat in "${bad_posture_patterns[@]}"; do
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      lineno="${m%%:*}"
      fail "contract_posture_purity" "matched pattern '$pat'" "$f" "$lineno"
    done < <(grep -nE "$pat" "$f" 2>/dev/null || true)
  done
done

# 6. Auth algorithm policy (all platform L2s).
for f in "${platform_arch_files[@]}"; do
  declare -a buf=()
  while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$f"
  n=${#buf[@]}
  for ((i=0; i<n; i++)); do
    line="${buf[i]}"
    if [[ "$line" == *"APP_JWT_SECRET"* ]]; then
      ctx="$line"
      [[ $i -gt 0 ]] && ctx+=" ${buf[i-1]}"
      [[ $((i+1)) -lt $n ]] && ctx+=" ${buf[i+1]}"
      shopt -s nocasematch
      qualified=0
      [[ "$ctx" == *BYOC* ]] && qualified=1
      [[ "$ctx" == *loopback* ]] && qualified=1
      [[ "$ctx" == *carve-out* ]] && qualified=1
      [[ "$ctx" == *allowlist* ]] && qualified=1
      [[ "$ctx" == *"no longer the standard"* ]] && qualified=1
      [[ "$ctx" == *"HmacValidator"* ]] && qualified=1
      [[ "$ctx" == *"only when"* ]] && qualified=1
      [[ "$ctx" == *"optional"* ]] && qualified=1
      shopt -u nocasematch
      if [[ $qualified -eq 0 ]]; then
        fail "auth_algorithm_policy" "APP_JWT_SECRET mentioned without BYOC/loopback/carve-out/allowlist/HmacValidator/optional qualifier" "$f" "$((i+1))"
      fi
    fi
  done
  unset buf
done

# 7. RLS pool lifecycle (L1/L2 architecture docs).
for f in "${non_docs_arch_files[@]}"; do
  declare -a buf=()
  while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$f"
  n=${#buf[@]}
  for ((i=0; i<n; i++)); do
    line="${buf[i]}"
    if [[ "$line" == *connectionInitSql* ]]; then
      bad=0
      if [[ "$line" =~ connectionInitSql[[:space:]]*=[[:space:]]*\'RESET[[:space:]]+ROLE.*RESET[[:space:]]+app\.tenant_id ]]; then
        bad=1
      fi
      if [[ "$line" == *"every checkout"* ]]; then
        shopt -s nocasematch
        if [[ ! "$line" =~ not[[:space:]]+on[[:space:]]+every[[:space:]]+checkout ]] && [[ ! "$line" =~ not[[:space:]]+.*every[[:space:]]+checkout ]]; then
          bad=1
        fi
        shopt -u nocasematch
      fi
      if [[ "$line" == *"between leases"* ]]; then
        shopt -s nocasematch
        if [[ ! "$line" =~ not[[:space:]]+.*between[[:space:]]+leases ]]; then
          bad=1
        fi
        shopt -u nocasematch
      fi
      if [[ $bad -eq 1 ]]; then
        fail "rls_pool_lifecycle" "doc claims 'connectionInitSql' is a per-checkout reset hook (HikariCP runs it only at connection creation)" "$f" "$((i+1))"
      fi
    fi
  done
  unset buf
done

# 7b. RLS pool lifecycle in security-control-matrix.md.
security_matrix="docs/security-control-matrix.md"
if [[ -f "$security_matrix" ]]; then
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    if [[ "$line" == *connectionInitSql* ]]; then
      fail "rls_pool_lifecycle_matrix" "security-control-matrix.md cites 'connectionInitSql' as a tenant reset control" "$security_matrix" "$lineno"
    fi
  done < "$security_matrix"
fi

# 7c. RLS reset vocabulary across L0/L1/L2 + governance + diagrams + matrix
#     (cycle-5 C2: scope expanded from cycle-4's governance-only).
declare -a rls_vocab_files=()
for f in "${non_docs_arch_files[@]}"; do rls_vocab_files+=("$f"); done
rls_vocab_files+=(
  "docs/governance/architecture-status.yaml"
  "docs/governance/decision-sync-matrix.md"
  "docs/trust-boundary-diagram.md"
  "docs/security-control-matrix.md"
)
declare -a rls_vocab_phrases=(
  "HikariCP reset"
  "HikariConnectionResetPolicy"
  "reset on connection check-in"
  "reset on check-in"
  "connection check-in reset"
)
for f in "${rls_vocab_files[@]}"; do
  [[ ! -f "$f" ]] && continue
  declare -a buf=()
  while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$f"
  n=${#buf[@]}
  for ((i=0; i<n; i++)); do
    line="${buf[i]}"
    for phrase in "${rls_vocab_phrases[@]}"; do
      if [[ "$line" == *"$phrase"* ]]; then
        shopt -s nocasematch
        allowed=0
        [[ "$line" == *"not "* ]] && allowed=1
        [[ "$line" == *"NOT "* ]] && allowed=1
        [[ "$line" == *"removed"* ]] && allowed=1
        [[ "$line" == *"deprecated"* ]] && allowed=1
        [[ "$line" == *"no longer"* ]] && allowed=1
        [[ "$line" == *"instead of"* ]] && allowed=1
        [[ "$line" == *"was wrong"* ]] && allowed=1
        [[ "$line" == *"cycle-2"* ]] && allowed=1
        [[ "$line" == *"cycle-3"* ]] && allowed=1
        [[ "$line" == *"cycle-4"* ]] && allowed=1
        [[ "$line" == *"cycle-5"* ]] && allowed=1
        shopt -u nocasematch
        if [[ $allowed -eq 0 ]]; then
          fail "rls_reset_vocabulary" "matched stale RLS reset wording '$phrase' without negation/deprecation marker" "$f" "$((i+1))"
        fi
      fi
    done
  done
  unset buf
done

# 7d. HS256 + prod conflict rule (cycle-5 D1).
# In docs/security-control-matrix.md, a control row mentioning HS256/HMAC and
# "prod" must explicitly say "rejected" or "not permitted" (because auth L2
# says prod has no HS256 path).
if [[ -f "$security_matrix" ]]; then
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    shopt -s nocasematch
    has_hs256=0
    [[ "$line" == *HS256* || "$line" == *"HMAC-SHA256"* ]] && has_hs256=1
    has_prod=0
    [[ "$line" == *"prod"* ]] && has_prod=1
    is_rejected=0
    [[ "$line" == *"rejected"* ]] && is_rejected=1
    [[ "$line" == *"not permitted"* ]] && is_rejected=1
    [[ "$line" == *"refused"* ]] && is_rejected=1
    shopt -u nocasematch
    if [[ $has_hs256 -eq 1 && $has_prod -eq 1 && $is_rejected -eq 0 ]]; then
      fail "hs256_prod_conflict" "control row mentions HS256 + prod without 'rejected' / 'not permitted' qualifier (auth L2 says prod has no HS256 path)" "$security_matrix" "$lineno"
    fi
  done < "$security_matrix"
fi

# 8. Gate path drift.
matrix="docs/governance/decision-sync-matrix.md"
if [[ -f "$matrix" ]]; then
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    if [[ "$line" =~ scripts/check_architecture_sync\. ]]; then
      fail "gate_path_drift" "decision-sync-matrix.md references scripts/check_architecture_sync.* but the canonical path is gate/" "$matrix" "$lineno"
    fi
  done < "$matrix"
fi

# 9. Gate log extension drift.
gate_readme="gate/README.md"
del_readme="docs/delivery/README.md"
if [[ -f "$gate_readme" && -f "$del_readme" ]]; then
  gate_ext=$(grep -oE 'gate/log/<sha>\.(json|txt)' "$gate_readme" | head -1 | sed 's/.*\.//')
  del_ext=$(grep -oE 'gate/log/<sha>\.(json|txt)' "$del_readme" | head -1 | sed 's/.*\.//')
  if [[ -n "$gate_ext" && -n "$del_ext" && "$gate_ext" != "$del_ext" ]]; then
    fail "gate_log_extension_drift" "gate/README.md says .$gate_ext but docs/delivery/README.md says .$del_ext" "gate/README.md;docs/delivery/README.md" 0
  fi
fi

# 10. Status enum sanity.
status_path="docs/governance/architecture-status.yaml"
if [[ -f "$status_path" ]]; then
  allowed_re='^(proposed|design_accepted|implemented_unverified|test_verified|operator_gated|released)$'
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    val=$(printf '%s\n' "$line" | sed -nE 's/^[[:space:]]*status:[[:space:]]*([A-Za-z_]+)[[:space:]]*$/\1/p')
    if [[ -n "$val" ]] && ! [[ "$val" =~ $allowed_re ]]; then
      fail "status_enum_invalid" "status '$val' is not in proposed|design_accepted|implemented_unverified|test_verified|operator_gated|released" "$status_path" "$lineno"
    fi
  done < "$status_path"
fi

# 11. L2 referenced but missing.
if [[ -f "$matrix" ]]; then
  refs=$(grep -oE '`(agent-[a-z0-9_/-]+/ARCHITECTURE\.md)`' "$matrix" | tr -d '`' | sort -u || true)
  while IFS= read -r r; do
    [[ -z "$r" ]] && continue
    if [[ ! -f "$r" ]]; then
      fail "l2_referenced_but_missing" "decision-sync-matrix.md references $r but the file does not exist" "$matrix" 0
    fi
  done <<< "$refs"
fi

# 12. L0 Last refreshed date.
if [[ -f ARCHITECTURE.md ]]; then
  if ! head -n 5 ARCHITECTURE.md | grep -F -q 'Last refreshed:** 2026-05-08'; then
    head_line=$(head -n 5 ARCHITECTURE.md | grep -F 'Last refreshed' | head -1 || true)
    fail "l0_stale_refresh_date" "L0 'Last refreshed' should be 2026-05-08; current: ${head_line:-<none>}" "ARCHITECTURE.md" 3
  fi
fi

# Compute final state.
sha_candidate="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
[[ -z "$sha_candidate" ]] && sha_candidate=no-git

semantic_fail_count=$((fail_count - dirty_tree_count))
semantic_pass=true
[[ $semantic_fail_count -gt 0 ]] && semantic_pass=false
evidence_valid=true
[[ "$tree_clean" == "false" ]] && evidence_valid=false
[[ "$semantic_pass" == "false" ]] && evidence_valid=false

# Cycle-5 A3: platform-suffix log filename.
if [[ "$evidence_valid" == "true" ]]; then
  log_dir="gate/log"
else
  log_dir="gate/log/local"
fi
mkdir -p "$log_dir"
log_path="$log_dir/${sha_candidate}-posix.json"

local_only_json=false
[[ $local_only -eq 1 ]] && local_only_json=true

porcelain_escaped="$(json_escape "$porcelain")"

{
  printf '{'
  printf '"script":"check_architecture_sync.sh",'
  printf '"version":"cycle-5-expanded",'
  printf '"platform":"posix",'
  printf '"sha":"%s",' "$sha_candidate"
  printf '"generated":"%s",' "$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '"scan_files_count":%d,' "${#all_scan_files[@]}"
  printf '"working_tree_clean":%s,' "$tree_clean"
  printf '"git_status_porcelain":"%s",' "$porcelain_escaped"
  printf '"local_only":%s,' "$local_only_json"
  printf '"semantic_pass":%s,' "$semantic_pass"
  printf '"evidence_valid_for_delivery":%s,' "$evidence_valid"
  printf '"failures":[%s]' "$failures_json"
  printf '}\n'
} > "$log_path"

if [[ $fail_count -gt 0 ]]; then
  echo "FAIL: $fail_count drift(s) found. See $log_path" >&2
  cat "$log_path" >&2
  exit 1
fi

if [[ "$evidence_valid" == "true" ]]; then
  ev_msg="evidence_valid_for_delivery=true"
else
  ev_msg="evidence_valid_for_delivery=false (local-only or dirty); log under gate/log/local/"
fi
echo "PASS: architecture corpus is internally consistent. $ev_msg. Log: $log_path"
exit 0
