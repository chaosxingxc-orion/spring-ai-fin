#!/usr/bin/env bash
# spring-ai-fin architecture-sync gate (cycle-2 expanded; POSIX bash).
# Catches drift classes from:
#   docs/systematic-architecture-improvement-plan-2026-05-07.en.md sec-4-2
#   docs/systematic-architecture-remediation-plan-2026-05-08.en.md sec-5 + sec-6 + sec-12
#   docs/systematic-architecture-remediation-plan-2026-05-08-cycle-2.en.md sec-4 through sec-9
#
# Default mode: fails if working tree is dirty.
# --local-only: permits dirty tree, writes evidence_valid_for_delivery=false.
#
# Architecture-sync gate, NOT Rule 8 operator-shape gate.

set -euo pipefail

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
--local-only mode permits dirty tree but writes evidence_valid_for_delivery=false.
EOF
      exit 0
      ;;
  esac
done

failures_json=""
fail_count=0
dirty_tree_count=0

# JSON-escape helper (handles common chars; strict ASCII).
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

[[ -f ARCHITECTURE.md ]] && { all_scan_files+=("ARCHITECTURE.md"); non_docs_arch_files+=("ARCHITECTURE.md"); }

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  all_scan_files+=("$f")
  non_docs_arch_files+=("$f")
done < <(find agent-platform agent-runtime -type f -name 'ARCHITECTURE.md' 2>/dev/null || true)

while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  case "$f" in
    *systematic-architecture-improvement-plan*) continue ;;
    *systematic-architecture-remediation-plan*) continue ;;
    *closure-taxonomy.md*) continue ;;
  esac
  all_scan_files+=("$f")
done < <(find docs -type f -name '*.md' 2>/dev/null || true)

# 1. Forbidden closure shortcuts (expanded scope).
forbidden_phrases=(
  "closes security review P0-"
  "closes security review P1-"
  "closed by design"
  "fixed in docs"
  "production-ready pending implementation"
  "accepted, therefore closed"
  "operator-gated by intention"
  "verified by review only"
)
for f in "${all_scan_files[@]}"; do
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    for phrase in "${forbidden_phrases[@]}"; do
      if [[ "$line" == *"$phrase"* ]]; then
        fail "forbidden_closure_shortcut" "matched '$phrase'" "$f" "$lineno"
      fi
    done
  done < "$f"
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

# 5. Contract posture purity.
ap_l1="agent-platform/ARCHITECTURE.md"
if [[ -f "$ap_l1" ]]; then
  bad_patterns=(
    'contracts read .* `Environment\.getProperty'
    'contracts read posture from .Environment'
    'Posture in .Environment\.getProperty. for contracts'
    'contracts/.* package reads .APP_POSTURE'
    'contracts read .* via .Environment'
  )
  for pat in "${bad_patterns[@]}"; do
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      lineno="${m%%:*}"
      fail "contract_posture_purity" "matched pattern '$pat'" "$ap_l1" "$lineno"
    done < <(grep -nE "$pat" "$ap_l1" 2>/dev/null || true)
  done
fi

# 6. Auth algorithm policy.
if [[ -f "$ap_l1" ]]; then
  declare -a buf=()
  while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$ap_l1"
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
      shopt -u nocasematch
      if [[ $qualified -eq 0 ]]; then
        fail "auth_algorithm_policy" "APP_JWT_SECRET mentioned without BYOC/loopback/carve-out/allowlist qualifier" "$ap_l1" "$((i+1))"
      fi
    fi
  done
  unset buf
fi

# 7. RLS pool lifecycle.
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
        # Allow if line says "not on every checkout" / "not.*every checkout"
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

# Emit structured log.
sha_candidate="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
[[ -z "$sha_candidate" ]] && sha_candidate=no-git
log_dir="gate/log"
mkdir -p "$log_dir"
log_path="$log_dir/${sha_candidate}.json"

semantic_fail_count=$((fail_count - dirty_tree_count))
semantic_pass=true
[[ $semantic_fail_count -gt 0 ]] && semantic_pass=false
evidence_valid=true
[[ "$tree_clean" == "false" ]] && evidence_valid=false
[[ "$semantic_pass" == "false" ]] && evidence_valid=false

local_only_json=false
[[ $local_only -eq 1 ]] && local_only_json=true

porcelain_escaped="$(json_escape "$porcelain")"

{
  printf '{'
  printf '"script":"check_architecture_sync.sh",'
  printf '"version":"cycle-2-expanded",'
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
  ev_msg="evidence_valid_for_delivery=false (local-only or dirty)"
fi
echo "PASS: architecture corpus is internally consistent. $ev_msg. Log: $log_path"
exit 0
