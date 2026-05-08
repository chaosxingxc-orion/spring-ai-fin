#!/usr/bin/env bash
# spring-ai-fin architecture-sync gate (cycle-6 expanded; POSIX bash).
# Catches drift classes from cycles 1-6.
#
# Cycle-6 changes:
#   - manifest_freshness rule: read docs/governance/evidence-manifest.yaml;
#     verify reviewed_sha names a delivery file + log that exist; warn (not
#     fail) if HEAD differs from reviewed_sha (audit-trail commit pattern).
#   - readme_to_files rule: gate/README.md must not say the operator-shape
#     smoke gate "does not exist" while the scripts are present.
#   - delivery_log_parity rule (basic): for each docs/delivery/2026-05-08-<sha>.md,
#     find matching gate/log/<sha>-{posix,windows}.json and compare key fields
#     (sha, semantic_pass, evidence_valid_for_delivery).
#   - auth_l2_hs256_prod rule: extend HS256/prod conflict check beyond
#     security-control-matrix.md to current auth L2 docs.

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
the log is written to gate/log/local/<sha>-posix.json (gitignored).
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

# 7c. RLS reset vocabulary (cycle-5: scope expanded to all L0/L1/L2).
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
        [[ "$line" == *"cycle-6"* ]] && allowed=1
        shopt -u nocasematch
        if [[ $allowed -eq 0 ]]; then
          fail "rls_reset_vocabulary" "matched stale RLS reset wording '$phrase' without negation/deprecation marker" "$f" "$((i+1))"
        fi
      fi
    done
  done
  unset buf
done

# 7d. HS256 + prod conflict (security-control-matrix + auth L2 — cycle-6 C1 extension).
hs_prod_scan_files=("$security_matrix" "agent-runtime/auth/ARCHITECTURE.md")
for f in "${hs_prod_scan_files[@]}"; do
  [[ ! -f "$f" ]] && continue
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    lineno=$((lineno + 1))
    shopt -s nocasematch
    has_hs256=0
    [[ "$line" == *HS256* || "$line" == *"HMAC-SHA256"* ]] && has_hs256=1
    has_hmac_secret=0
    [[ "$line" == *"APP_JWT_SECRET"* ]] && has_hmac_secret=1
    has_prod=0
    [[ "$line" == *"prod"* ]] && has_prod=1
    is_rejected=0
    [[ "$line" == *"rejected"* ]] && is_rejected=1
    [[ "$line" == *"not permitted"* ]] && is_rejected=1
    [[ "$line" == *"refused"* ]] && is_rejected=1
    [[ "$line" == *"reject HmacValidator"* ]] && is_rejected=1
    [[ "$line" == *"not a prod boot input"* ]] && is_rejected=1
    [[ "$line" == *"HmacValidator is active"* ]] && is_rejected=1
    [[ "$line" == *"only when"* ]] && is_rejected=1
    # Accept policy phrases that describe the legitimate posture-aware policy
    # without being a posture-row column.
    [[ "$line" == *"no HS256 path"* ]] && is_rejected=1
    [[ "$line" == *"HS256 only for"* ]] && is_rejected=1
    [[ "$line" == *"HS256 only on"* ]] && is_rejected=1
    [[ "$line" == *"only for DEV"* ]] && is_rejected=1
    [[ "$line" == *"only for dev"* ]] && is_rejected=1
    [[ "$line" == *"only for BYOC"* ]] && is_rejected=1
    [[ "$line" == *"only for byoc"* ]] && is_rejected=1
    [[ "$line" == *"mandatory for"* ]] && is_rejected=1
    [[ "$line" == *"mandatory regardless"* ]] && is_rejected=1
    [[ "$line" == *"explicit BYOC"* ]] && is_rejected=1
    [[ "$line" == *"explicit byoc"* ]] && is_rejected=1
    [[ "$line" == *"carve-out only"* ]] && is_rejected=1
    [[ "$line" == *"with carve-out"* ]] && is_rejected=1
    [[ "$line" == *"loopback only"* ]] && is_rejected=1
    shopt -u nocasematch
    if [[ ($has_hs256 -eq 1 || $has_hmac_secret -eq 1) && $has_prod -eq 1 && $is_rejected -eq 0 ]]; then
      fail "hs256_prod_conflict" "doc mentions HS256/APP_JWT_SECRET + prod without rejected/not-permitted qualifier" "$f" "$lineno"
    fi
  done < "$f"
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

# 13. Manifest freshness (cycle-6 A2).
manifest_path="docs/governance/evidence-manifest.yaml"
if [[ -f "$manifest_path" ]]; then
  manifest_sha=$(grep -E '^reviewed_sha:' "$manifest_path" | head -1 | sed -E 's/^reviewed_sha:[[:space:]]*([A-Za-z0-9]+).*/\1/')
  manifest_delivery=$(grep -E '^delivery_file:' "$manifest_path" | head -1 | sed -E 's/^delivery_file:[[:space:]]*(.*)/\1/')
  if [[ -n "$manifest_sha" && "$manifest_sha" != "TBD" ]]; then
    # Delivery file existence
    if [[ -n "$manifest_delivery" && ! -f "$manifest_delivery" ]]; then
      fail "manifest_freshness" "manifest.delivery_file references '$manifest_delivery' which does not exist" "$manifest_path" 0
    fi
    # Architecture-sync log existence (posix or windows)
    posix_log="gate/log/${manifest_sha}-posix.json"
    windows_log="gate/log/${manifest_sha}-windows.json"
    legacy_log="gate/log/${manifest_sha}.json"
    if [[ ! -f "$posix_log" && ! -f "$windows_log" && ! -f "$legacy_log" ]]; then
      fail "manifest_freshness" "manifest.reviewed_sha=$manifest_sha but no matching log exists ($posix_log, $windows_log, or $legacy_log)" "$manifest_path" 0
    fi
  fi
fi

# 14. README to files (cycle-6 B2).
if [[ -f "$gate_readme" ]]; then
  smoke_ps1=gate/run_operator_shape_smoke.ps1
  smoke_sh=gate/run_operator_shape_smoke.sh
  if [[ -f "$smoke_ps1" || -f "$smoke_sh" ]]; then
    # Scripts exist; README must not say "smoke gate does not exist"
    lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      lineno=$((lineno + 1))
      shopt -s nocasematch
      bad=0
      if [[ "$line" == *"smoke gate"* && "$line" == *"does not exist"* ]]; then
        bad=1
      fi
      if [[ "$line" == *"smoke gate"* && "$line" == *"not yet exist"* ]]; then
        bad=1
      fi
      if [[ "$line" == *"run_operator_shape_smoke"* && "$line" == *"absent"* ]]; then
        bad=1
      fi
      if [[ "$line" == *"run_operator_shape_smoke"* && "$line" == *"does not exist"* ]]; then
        bad=1
      fi
      shopt -u nocasematch
      if [[ $bad -eq 1 ]]; then
        fail "readme_to_files" "gate/README.md says smoke gate does not exist while scripts are present in gate/" "$gate_readme" "$lineno"
      fi
    done < "$gate_readme"
  fi
fi

# 15. Delivery-log parity (cycle-6 B3, basic).
# For each docs/delivery/2026-05-08-<sha>.md, find matching log and compare key fields.
while IFS= read -r dfile; do
  [[ -z "$dfile" ]] && continue
  base=$(basename "$dfile" .md)
  # Extract <sha> from "2026-05-08-<sha>"
  sha=${base##2026-05-08-}
  [[ -z "$sha" ]] && continue
  # Skip placeholder names like "d284232" (local-only) — we only check delivery-valid SHAs
  posix_log="gate/log/${sha}-posix.json"
  windows_log="gate/log/${sha}-windows.json"
  legacy_log="gate/log/${sha}.json"
  log_file=""
  if [[ -f "$posix_log" ]]; then log_file="$posix_log"
  elif [[ -f "$windows_log" ]]; then log_file="$windows_log"
  elif [[ -f "$legacy_log" ]]; then log_file="$legacy_log"
  fi
  [[ -z "$log_file" ]] && continue
  # Extract fields from log JSON
  log_sha=$(grep -oE '"sha":"[^"]*"' "$log_file" | head -1 | sed -E 's/.*"sha":"([^"]*)".*/\1/')
  log_semantic_pass=$(grep -oE '"semantic_pass":(true|false)' "$log_file" | head -1 | sed -E 's/.*:(.*)/\1/')
  log_evidence_valid=$(grep -oE '"evidence_valid_for_delivery":(true|false)' "$log_file" | head -1 | sed -E 's/.*:(.*)/\1/')
  # Verify log_sha matches expected sha
  if [[ "$log_sha" != "$sha" ]]; then
    fail "delivery_log_parity" "log $log_file reports sha='$log_sha' but the filename names sha='$sha'" "$log_file" 0
  fi
  # Verify delivery file mentions matching values (basic check on semantic_pass)
  if grep -E '\| `semantic_pass` \|' "$dfile" >/dev/null 2>&1; then
    delivery_semantic=$(grep -E '\| `semantic_pass` \|' "$dfile" | head -1 | grep -oE '(true|false|`true`|`false`)' | head -1 | tr -d '`')
    if [[ -n "$delivery_semantic" && -n "$log_semantic_pass" && "$delivery_semantic" != "$log_semantic_pass" ]]; then
      fail "delivery_log_parity" "delivery file says semantic_pass=$delivery_semantic but log says $log_semantic_pass" "$dfile" 0
    fi
  fi
  if grep -E '\| `evidence_valid_for_delivery` \|' "$dfile" >/dev/null 2>&1; then
    delivery_ev=$(grep -E '\| `evidence_valid_for_delivery` \|' "$dfile" | head -1 | grep -oE '(true|false|\*\*`true`\*\*|\*\*`false`\*\*|`true`|`false`)' | head -1 | tr -d '`*')
    if [[ -n "$delivery_ev" && -n "$log_evidence_valid" && "$delivery_ev" != "$log_evidence_valid" ]]; then
      fail "delivery_log_parity" "delivery file says evidence_valid_for_delivery=$delivery_ev but log says $log_evidence_valid" "$dfile" 0
    fi
  fi
done < <(find docs/delivery -maxdepth 1 -type f -name '2026-05-08-*.md' 2>/dev/null || true)

# Compute final state.
sha_candidate="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
[[ -z "$sha_candidate" ]] && sha_candidate=no-git

semantic_fail_count=$((fail_count - dirty_tree_count))
semantic_pass=true
[[ $semantic_fail_count -gt 0 ]] && semantic_pass=false
evidence_valid=true
[[ "$tree_clean" == "false" ]] && evidence_valid=false
[[ "$semantic_pass" == "false" ]] && evidence_valid=false

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
  printf '"version":"cycle-6-expanded",'
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
