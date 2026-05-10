#!/usr/bin/env bash
# spring-ai-fin architecture-sync gate (cycle-8 evidence graph v3; POSIX bash).
# Catches drift classes from cycles 1-8.
#
# Cycle-8 changes (this version: "cycle-9-truth-cut"):
#   - eol_policy rule (A1): tracked *.sh must be LF in working tree.
#   - delivery_log_exact_binding rule (B1): authoritative delivery files
#     MUST name a log path that exists and whose sha equals
#     reviewed_content_sha or evidence_commit_sha.
#   - delivery_log_parity (B2): no skip on missing log for current
#     authoritative delivery; legacy exemptions are explicit in manifest.
#   - manifest_no_tbd rule (B3): "TBD" forbidden in delivery-valid manifest
#     identity fields.
#   - manifest_no_null_log_slots rule (B3): log state slots use the closed
#     enum, not null.
#   - ascii_only_active_corpus rule (D1): replaces ascii_only_governance;
#     scan list derived from docs/governance/active-corpus.yaml.
#   - rule_8_state_consistency rule (C2): when rule_8.state ==
#     fail_closed_artifact_missing, no capability has maturity L3 or
#     evidence_state operator_gated; no delivery file claims Rule 8 PASS.
#
# Cycle-7 baseline (unchanged):
#   - audit_trail_shape rule (B1): two-SHA evidence model.
#   - manifest_edge_consistency rule (B2).
#   - capability_legacy_bucket rule (D2).
#   - Variable initialization above all rules; rule body try-wrapped.

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
--local-only mode permits dirty tree; non-delivery-valid logs go to
gate/log/local/<sha>-posix.json (gitignored).
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

# Shared variables (cycle-7 A1: must precede any rule).
gate_readme="gate/README.md"
del_readme="docs/delivery/README.md"
security_matrix="docs/security-control-matrix.md"
matrix="docs/governance/decision-sync-matrix.md"
status_path="docs/governance/architecture-status.yaml"
manifest_path="docs/governance/evidence-manifest.yaml"
index_path="docs/governance/current-architecture-index.md"
ag_l2="agent-runtime/action/ARCHITECTURE.md"
ag_l2_legacy="agent-runtime/action-guard/ARCHITECTURE.md"
ap_l1="agent-platform/ARCHITECTURE.md"
l0="ARCHITECTURE.md"

sha_candidate="$(git rev-parse --short HEAD 2>/dev/null || echo no-git)"
[[ -z "$sha_candidate" ]] && sha_candidate=no-git

rule_body_succeeded=true
runtime_error_message=""

# Wrap rule body so a runtime error emits structured JSON.
{
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

  [[ -f $l0 ]] && { all_scan_files+=("$l0"); non_docs_arch_files+=("$l0"); }

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

  # 1b. Forbidden closure shortcuts: regex.
  declare -a closure_regex_names=(
    "closes_pn_phrase" "pn_closure_phrase" "closure_rests_on_phrase"
    "closed_by_design_phrase" "fixed_in_docs_phrase" "accepted_therefore_closed_phrase"
  )
  declare -a closure_regex_patterns=(
    '\bcloses?\s+(security\s+review\s+)?(sec-)?P[0-9]+-[0-9]+\b'
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
  saga_phrases=("strong within saga" "cross-entity strong consistency" "all-or-nothing across step failure points")
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

  # 4. ActionGuard 5-stage invariants (cycle-9 sec-C2).
  # Rule migrated from action-guard/ to action/ per the cycle-9 truth-cut.
  # Binds to the refresh-active path; the legacy 11-stage path is in
  # transitional_rationale and the gate must NOT validate it as active.
  if [[ -f "$ag_l2" ]]; then
    # 5-stage names must all be present.
    for stage in "Authenticate" "Authorize" "Bound" "Execute" "Witness"; do
      if ! grep -F -q "$stage" "$ag_l2"; then
        fail "actionguard_5stage_invariants" "action L2 does not mention 5-stage name '$stage'" "$ag_l2" 0
      fi
    done
    # Audit-before-action invariant: must explicitly say audit + outbox happen on Witness, not on Execute.
    # Post-failure-evidence invariant: must explicitly say audit row written on terminal regardless of Execute success.
    if ! grep -E -q '(audit row|audit log|append-only|INSERT-only)' "$ag_l2"; then
      fail "actionguard_5stage_invariants" "action L2 does not mention audit-row invariant" "$ag_l2" 0
    fi
    if ! grep -E -q '(outbox event|outbox row|outbox_event)' "$ag_l2"; then
      fail "actionguard_5stage_invariants" "action L2 does not mention outbox-event invariant" "$ag_l2" 0
    fi
  fi

  # 5. Contract posture purity.
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

  # 6. Auth algorithm policy.
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
        for q in BYOC loopback carve-out allowlist 'no longer the standard' HmacValidator 'only when' optional; do
          [[ "$ctx" == *"$q"* ]] && qualified=1
        done
        shopt -u nocasematch
        if [[ $qualified -eq 0 ]]; then
          fail "auth_algorithm_policy" "APP_JWT_SECRET mentioned without qualifier" "$f" "$((i+1))"
        fi
      fi
    done
    unset buf
  done

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
          shopt -s nocasematch
          if [[ ! "$line" =~ not[[:space:]]+on[[:space:]]+every[[:space:]]+checkout ]] && [[ ! "$line" =~ not[[:space:]]+.*every[[:space:]]+checkout ]]; then
            bad=1
          fi
          shopt -u nocasematch
        fi
        if [[ "$line" == *"between leases"* ]]; then
          shopt -s nocasematch
          if [[ ! "$line" =~ not[[:space:]]+.*between[[:space:]]+leases ]]; then bad=1; fi
          shopt -u nocasematch
        fi
        if [[ $bad -eq 1 ]]; then
          fail "rls_pool_lifecycle" "doc claims 'connectionInitSql' is per-checkout reset hook" "$f" "$((i+1))"
        fi
      fi
    done
    unset buf
  done

  # 7b. RLS pool lifecycle in security-control-matrix.md.
  if [[ -f "$security_matrix" ]]; then
    lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      lineno=$((lineno + 1))
      if [[ "$line" == *connectionInitSql* ]]; then
        fail "rls_pool_lifecycle_matrix" "security-control-matrix.md cites 'connectionInitSql' as a tenant reset control" "$security_matrix" "$lineno"
      fi
    done < "$security_matrix"
  fi

  # 7c. RLS reset vocabulary.
  declare -a rls_vocab_files=()
  for f in "${non_docs_arch_files[@]}"; do rls_vocab_files+=("$f"); done
  rls_vocab_files+=("$status_path" "$matrix" "docs/trust-boundary-diagram.md" "$security_matrix")
  declare -a rls_vocab_phrases=("HikariCP reset" "HikariConnectionResetPolicy" "reset on connection check-in" "reset on check-in" "connection check-in reset")
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
          for q in 'not ' 'NOT ' removed deprecated 'no longer' 'instead of' 'was wrong' cycle-2 cycle-3 cycle-4 cycle-5 cycle-6 cycle-7; do
            [[ "$line" == *"$q"* ]] && allowed=1
          done
          shopt -u nocasematch
          if [[ $allowed -eq 0 ]]; then
            fail "rls_reset_vocabulary" "stale RLS reset wording '$phrase' without negation/deprecation marker" "$f" "$((i+1))"
          fi
        fi
      done
    done
    unset buf
  done

  # 7d. HS256 + prod conflict.
  hs_prod_scan_files=("$security_matrix" "agent-runtime/auth/ARCHITECTURE.md")
  for f in "${hs_prod_scan_files[@]}"; do
    [[ ! -f "$f" ]] && continue
    lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      lineno=$((lineno + 1))
      shopt -s nocasematch
      has_hs256=0
      [[ "$line" == *HS256* || "$line" == *"HMAC-SHA256"* || "$line" == *"APP_JWT_SECRET"* ]] && has_hs256=1
      has_prod=0
      [[ "$line" == *"prod"* ]] && has_prod=1
      is_rejected=0
      for q in rejected 'not permitted' refused 'reject HmacValidator' 'not a prod boot input' 'HmacValidator is active' 'only when' 'no HS256 path' 'HS256 only for' 'HS256 only on' 'only for DEV' 'only for BYOC' 'mandatory for' 'mandatory regardless' 'explicit BYOC' 'carve-out only' 'with carve-out' 'loopback only'; do
        [[ "$line" == *"$q"* ]] && is_rejected=1
      done
      shopt -u nocasematch
      if [[ $has_hs256 -eq 1 && $has_prod -eq 1 && $is_rejected -eq 0 ]]; then
        fail "hs256_prod_conflict" "doc mentions HS256/APP_JWT_SECRET + prod without rejection qualifier" "$f" "$lineno"
      fi
    done < "$f"
  done

  # 8. Gate path drift.
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
  if [[ -f "$gate_readme" && -f "$del_readme" ]]; then
    gate_ext=$(grep -oE 'gate/log/<sha>\.(json|txt)' "$gate_readme" | head -1 | sed 's/.*\.//')
    del_ext=$(grep -oE 'gate/log/<sha>\.(json|txt)' "$del_readme" | head -1 | sed 's/.*\.//')
    if [[ -n "$gate_ext" && -n "$del_ext" && "$gate_ext" != "$del_ext" ]]; then
      fail "gate_log_extension_drift" "gate/README.md says .$gate_ext but docs/delivery/README.md says .$del_ext" "$gate_readme;$del_readme" 0
    fi
  fi

  # 10. Status enum sanity.
  if [[ -f "$status_path" ]]; then
    allowed_re='^(proposed|design_accepted|implemented_unverified|test_verified|operator_gated|released)$'
    lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      lineno=$((lineno + 1))
      val=$(printf '%s\n' "$line" | sed -nE 's/^[[:space:]]*status:[[:space:]]*([A-Za-z_]+)[[:space:]]*$/\1/p')
      if [[ -n "$val" ]] && ! [[ "$val" =~ $allowed_re ]]; then
        fail "status_enum_invalid" "status '$val' is not in allowed list" "$status_path" "$lineno"
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

  # 12. L0 Last refreshed.
  if [[ -f "$l0" ]]; then
    if ! head -n 5 "$l0" | grep -F -q 'Last refreshed:** 2026-05-08'; then
      head_line=$(head -n 5 "$l0" | grep -F 'Last refreshed' | head -1 || true)
      fail "l0_stale_refresh_date" "L0 'Last refreshed' should be 2026-05-08; current: ${head_line:-<none>}" "$l0" 3
    fi
  fi

  # 13. Manifest freshness (cycle-6 + cycle-7 v2 schema).
  reviewed_content_sha=""
  evidence_commit_sha=""
  evidence_classification=""
  manifest_delivery=""
  if [[ -f "$manifest_path" ]]; then
    while IFS= read -r line; do
      stripped="${line%%#*}"
      stripped="${stripped%"${stripped##*[![:space:]]}"}"
      case "$stripped" in
        reviewed_content_sha:*) reviewed_content_sha=$(printf '%s' "$stripped" | sed -E 's/^reviewed_content_sha:[[:space:]]*([A-Za-z0-9]+).*/\1/') ;;
        evidence_commit_sha:*) evidence_commit_sha=$(printf '%s' "$stripped" | sed -E 's/^evidence_commit_sha:[[:space:]]*([A-Za-z0-9]+).*/\1/') ;;
        evidence_commit_classification:*) evidence_classification=$(printf '%s' "$stripped" | sed -E 's/^evidence_commit_classification:[[:space:]]*([A-Za-z_]+).*/\1/') ;;
        delivery_file:*) manifest_delivery=$(printf '%s' "$stripped" | sed -E 's/^delivery_file:[[:space:]]*(.+)/\1/') ;;
        reviewed_sha:*) [[ -z "$reviewed_content_sha" ]] && reviewed_content_sha=$(printf '%s' "$stripped" | sed -E 's/^reviewed_sha:[[:space:]]*([A-Za-z0-9]+).*/\1/') ;;
      esac
    done < "$manifest_path"
    if [[ -n "$reviewed_content_sha" && "$reviewed_content_sha" != "TBD" ]]; then
      # delivery_file existence is the only file-existence check here.
      # Log-existence at <reviewed_content_sha> is NOT required: the
      # audit-trail-commit pattern (cycle-6 + cycle-7 sec-B1) means a
      # delivery-valid log at the architectural SHA cannot exist without
      # git-amend gymnastics. The structural relationship is enforced by
      # audit_trail_shape (uses git rev-parse + git diff --name-only,
      # not file paths). delivery_log_parity verifies the field semantics
      # of any log that does exist.
      if [[ -n "$manifest_delivery" && ! -f "$manifest_delivery" ]]; then
        fail "manifest_freshness" "manifest.delivery_file=$manifest_delivery does not exist" "$manifest_path" 0
      fi
      # Verify reviewed_content_sha is a valid git SHA reachable from HEAD.
      if ! git merge-base --is-ancestor "$reviewed_content_sha" HEAD 2>/dev/null; then
        # Allow if reviewed_content_sha equals HEAD (direct case).
        if [[ "$sha_candidate" != "$reviewed_content_sha" ]]; then
          fail "manifest_freshness" "manifest.reviewed_content_sha=$reviewed_content_sha is not reachable from HEAD" "$manifest_path" 0
        fi
      fi
    fi
  fi

  # 13b. Audit-trail shape (cycle-7 B1).
  # Derive evidence_commit_sha from HEAD (it's always HEAD by definition;
  # storing it in the manifest as TBD/explicit is optional). The structural
  # constraints are: parent equality, allowed-paths subset.
  if [[ -n "$reviewed_content_sha" && "$sha_candidate" != "no-git" ]]; then
    if [[ "$sha_candidate" == "$reviewed_content_sha" ]]; then
      :   # Direct: HEAD == reviewed content
    else
      parent_sha=$(git rev-parse --short HEAD^ 2>/dev/null || true)
      if [[ -z "$parent_sha" ]]; then
        fail "audit_trail_shape" "HEAD ($sha_candidate) != reviewed_content_sha ($reviewed_content_sha) and HEAD has no parent" "$manifest_path" 0
      elif [[ "$parent_sha" != "$reviewed_content_sha" ]]; then
        fail "audit_trail_shape" "HEAD ($sha_candidate) parent is $parent_sha but manifest.reviewed_content_sha is $reviewed_content_sha; expected one-parent audit-trail shape" "$manifest_path" 0
      else
        # Verify changed paths are a subset of allowed_audit_trail_paths.
        changed_paths=$(git diff --name-only "${reviewed_content_sha}..HEAD" 2>/dev/null || true)
        while IFS= read -r cp; do
          [[ -z "$cp" ]] && continue
          allowed=0
          for pat in '^docs/delivery/' '^docs/governance/architecture-status\.yaml$' '^docs/governance/current-architecture-index\.md$' '^docs/governance/evidence-manifest\.yaml$' '^gate/log/'; do
            if [[ "$cp" =~ $pat ]]; then allowed=1; break; fi
          done
          if [[ $allowed -eq 0 ]]; then
            fail "audit_trail_shape" "audit-trail commit changed disallowed path: $cp" "$manifest_path" 0
          fi
        done <<< "$changed_paths"
      fi
    fi
  fi

  # 13c. Manifest-edge consistency (cycle-7 B2).
  if [[ -n "$reviewed_content_sha" && -f "$status_path" ]]; then
    if ! grep -F -q "$reviewed_content_sha" "$status_path"; then
      fail "manifest_edge_consistency" "architecture-status.yaml does not reference manifest.reviewed_content_sha=$reviewed_content_sha" "$status_path" 0
    fi
  fi
  if [[ -n "$manifest_delivery" && -f "$index_path" ]]; then
    delivery_base=$(basename "$manifest_delivery")
    if ! grep -F -q "$delivery_base" "$index_path"; then
      fail "manifest_edge_consistency" "current-architecture-index.md does not reference manifest.delivery_file=$delivery_base" "$index_path" 0
    fi
  fi

  # 14. README to files.
  smoke_ps1="gate/run_operator_shape_smoke.ps1"
  smoke_sh="gate/run_operator_shape_smoke.sh"
  if [[ -f "$gate_readme" ]] && { [[ -f "$smoke_ps1" ]] || [[ -f "$smoke_sh" ]]; }; then
    declare -a buf=()
    while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$gate_readme"
    n=${#buf[@]}
    for ((i=0; i<n; i++)); do
      line="${buf[i]}"
      bad=0
      shopt -s nocasematch
      if [[ "$line" == *"smoke gate"* ]] && { [[ "$line" == *"does not exist"* ]] || [[ "$line" == *"not yet exist"* ]]; }; then bad=1; fi
      if [[ "$line" == *"run_operator_shape_smoke"* ]] && { [[ "$line" == *"does not exist"* ]] || [[ "$line" == *"absent"* ]]; }; then bad=1; fi
      shopt -u nocasematch
      if [[ $bad -eq 1 ]]; then
        fail "readme_to_files" "gate/README.md says smoke gate does not exist while scripts are present" "$gate_readme" "$((i+1))"
      fi
    done
    unset buf
  fi

  # 15. Delivery-log parity (cycle-7 A2; cycle-8 B2 no-skip-on-missing for
  # current authoritative delivery; legacy_exemptions explicit in manifest).
  while IFS= read -r dfile; do
    [[ -z "$dfile" ]] && continue
    base=$(basename "$dfile" .md)
    sha=${base##2026-05-08-}
    [[ -z "$sha" ]] && continue
    log_file=""
    for candidate in "gate/log/${sha}-posix.json" "gate/log/${sha}-windows.json" "gate/log/${sha}.json"; do
      if [[ -f "$candidate" ]]; then log_file="$candidate"; break; fi
    done
    if [[ -z "$log_file" ]]; then
      # Cycle-8 B2: do not silently skip. Either the delivery is the current
      # authoritative one (manifest.delivery_file) -> FAIL; or it's listed
      # under manifest.architecture_sync_logs.legacy_exemptions -> OK; or
      # it's an older delivery whose platform-suffix log was archived ->
      # treat as historical_only and emit a NOTE-level non-failing record.
      legacy_exempt=0
      if grep -F -q "$dfile" "$manifest_path" 2>/dev/null; then
        if grep -F -A5 "$dfile" "$manifest_path" 2>/dev/null | grep -F -q "pre_platform_suffix_legacy"; then
          legacy_exempt=1
        fi
      fi
      if [[ "$dfile" == "$manifest_delivery" && $legacy_exempt -eq 0 ]]; then
        fail "delivery_log_parity" "current authoritative delivery $dfile has no matching gate/log/${sha}-*.json" "$dfile" 0
      fi
      continue
    fi
    log_sha=$(grep -oE '"sha":"[^"]*"' "$log_file" | head -1 | sed -E 's/.*"sha":"([^"]*)".*/\1/')
    log_sem=$(grep -oE '"semantic_pass":(true|false)' "$log_file" | head -1 | sed -E 's/.*:(.*)/\1/')
    log_ev=$(grep -oE '"evidence_valid_for_delivery":(true|false)' "$log_file" | head -1 | sed -E 's/.*:(.*)/\1/')
    if [[ "$log_sha" != "$sha" ]]; then
      fail "delivery_log_parity" "log $log_file reports sha='$log_sha' but the filename names sha='$sha'" "$log_file" 0
    fi
    if grep -E '\| `semantic_pass` \|' "$dfile" >/dev/null 2>&1; then
      ds=$(grep -E '\| `semantic_pass` \|' "$dfile" | head -1 | grep -oE '(true|false|`true`|`false`|\*\*true\*\*|\*\*false\*\*|\*\*`true`\*\*|\*\*`false`\*\*)' | head -1 | tr -d '`*')
      if [[ -n "$ds" && -n "$log_sem" && "$ds" != "$log_sem" ]]; then
        fail "delivery_log_parity" "delivery says semantic_pass=$ds but log says $log_sem" "$dfile" 0
      fi
    fi
    if grep -E '\| `evidence_valid_for_delivery` \|' "$dfile" >/dev/null 2>&1; then
      de=$(grep -E '\| `evidence_valid_for_delivery` \|' "$dfile" | head -1 | grep -oE '(true|false|`true`|`false`|\*\*true\*\*|\*\*false\*\*|\*\*`true`\*\*|\*\*`false`\*\*)' | head -1 | tr -d '`*')
      if [[ -n "$de" && -n "$log_ev" && "$de" != "$log_ev" ]]; then
        fail "delivery_log_parity" "delivery says evidence_valid_for_delivery=$de but log says $log_ev" "$dfile" 0
      fi
    fi
  done < <(find docs/delivery -maxdepth 1 -type f -name '2026-05-08-*.md' 2>/dev/null || true)

  # 16. ASCII-only active corpus (cycle-8 D1; cycle-9 split-aware).
  # Scan list is derived from docs/governance/active-corpus.yaml#active_documents
  # ONLY -- never from transitional_rationale or historical_documents.
  active_corpus_path="docs/governance/active-corpus.yaml"
  declare -a ascii_files=()
  declare -a active_paths=()
  if [[ -f "$active_corpus_path" ]]; then
    in_active=0
    while IFS= read -r yline || [[ -n "$yline" ]]; do
      if [[ "$yline" == "active_documents:" ]]; then in_active=1; continue; fi
      if [[ "$yline" == "transitional_rationale:" ]]; then in_active=0; continue; fi
      if [[ "$yline" == "historical_documents:" ]]; then in_active=0; continue; fi
      [[ $in_active -eq 0 ]] && continue
      if [[ "$yline" =~ ^[[:space:]]+-[[:space:]]+path:[[:space:]]+(.+)$ ]]; then
        ap="${BASH_REMATCH[1]}"
        ap="${ap%%[[:space:]]*}"
        ascii_files+=("$ap")
        active_paths+=("$ap")
      fi
    done < "$active_corpus_path"
  fi
  if [[ ${#ascii_files[@]} -eq 0 ]]; then
    # Fallback: cycle-7 minimal set so a malformed registry never silently
    # disables encoding enforcement.
    ascii_files=(
      "$manifest_path" "$index_path" "$status_path"
      "docs/governance/closure-taxonomy.md" "docs/governance/decision-sync-matrix.md"
      "docs/governance/maturity-glossary.md" "$del_readme" "$gate_readme"
    )
    fail "active_corpus_registry_missing" "active-corpus.yaml not parseable; falling back to cycle-7 minimal scan list" "$active_corpus_path" 0
  fi
  for f in "${ascii_files[@]}"; do
    [[ ! -f "$f" ]] && continue
    if LC_ALL=C grep -q '[^[:print:][:space:]]' "$f" 2>/dev/null; then
      lineno=$(LC_ALL=C grep -n '[^[:print:][:space:]]' "$f" 2>/dev/null | head -1 | cut -d: -f1)
      fail "ascii_only_active_corpus" "non-ASCII byte found" "$f" "${lineno:-0}"
    fi
  done

  # 18. EOL policy (cycle-8 A1): tracked *.sh files must be LF in working tree.
  while IFS= read -r shf; do
    [[ -z "$shf" ]] && continue
    [[ ! -f "$shf" ]] && continue
    if grep -q $'\r' "$shf" 2>/dev/null; then
      fail "eol_policy" "shell script contains CRLF; must be LF (see .gitattributes)" "$shf" 0
    fi
  done < <(git ls-files '*.sh' 2>/dev/null || true)
  if [[ ! -f .gitattributes ]]; then
    fail "eol_policy" ".gitattributes does not exist; LF policy is unenforced" ".gitattributes" 0
  fi

  # 19. Manifest no TBD / no null log slots (cycle-8 B3).
  if [[ -f "$manifest_path" ]]; then
    lineno=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      lineno=$((lineno + 1))
      stripped="${line%%#*}"
      # Forbid bare TBD as a value.
      if [[ "$stripped" =~ :[[:space:]]*TBD[[:space:]]*$ ]]; then
        fail "manifest_no_tbd" "manifest has 'TBD' value; replace with explicit value or state" "$manifest_path" "$lineno"
      fi
      # Forbid bare null in 'state:' fields (other null is allowed during
      # pre_audit_trail). The state field is the contract per Phase 1.
      if [[ "$stripped" =~ ^[[:space:]]+state:[[:space:]]*null[[:space:]]*$ ]]; then
        fail "manifest_no_null_log_slots" "manifest has 'state: null'; use the closed state enum" "$manifest_path" "$lineno"
      fi
    done < "$manifest_path"
  fi

  # 20. Delivery-log exact binding (cycle-8 B1).
  # For the current authoritative delivery file (manifest.delivery_file),
  # require: a log path declared (in architecture_sync_logs.<platform>.path
  # OR derivable from <delivery-sha>-{posix,windows,legacy}.json), the log
  # exists, and the log's sha equals reviewed_content_sha or HEAD (the
  # evidence_commit_sha).
  if [[ -n "$manifest_delivery" && -f "$manifest_delivery" && -n "$reviewed_content_sha" ]]; then
    delivery_base=$(basename "$manifest_delivery" .md)
    delivery_sha=$(echo "$delivery_base" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}-//')
    found_log=""
    for candidate in "gate/log/${delivery_sha}-posix.json" "gate/log/${delivery_sha}-windows.json" "gate/log/${delivery_sha}.json"; do
      if [[ -f "$candidate" ]]; then found_log="$candidate"; break; fi
    done
    # Legacy exemption check: scan manifest for legacy_exemptions block.
    legacy_exempt=0
    if grep -F -q "$manifest_delivery" "$manifest_path" 2>/dev/null; then
      if grep -F -A5 "$manifest_delivery" "$manifest_path" 2>/dev/null | grep -F -q "pre_platform_suffix_legacy"; then
        legacy_exempt=1
      fi
    fi
    if [[ -z "$found_log" && $legacy_exempt -eq 0 ]]; then
      fail "delivery_log_exact_binding" "manifest.delivery_file=$manifest_delivery has no matching gate/log/${delivery_sha}-*.json (and no legacy exemption)" "$manifest_path" 0
    fi
    if [[ -n "$found_log" ]]; then
      log_sha_field=$(grep -oE '"sha":"[^"]*"' "$found_log" | head -1 | sed -E 's/.*"sha":"([^"]*)".*/\1/')
      head_short="$sha_candidate"
      if [[ -n "$log_sha_field" && "$log_sha_field" != "$reviewed_content_sha" && "$log_sha_field" != "$head_short" ]]; then
        fail "delivery_log_exact_binding" "log $found_log reports sha='$log_sha_field' which is neither reviewed_content_sha=$reviewed_content_sha nor HEAD=$head_short" "$found_log" 0
      fi
    fi
  fi

  # 22. Active corpus exclusivity (cycle-9 A1, B1): no active_documents
  # entry may carry a v7_disposition / supersedes_to / sunset_by marker.
  if [[ -f "$active_corpus_path" ]]; then
    in_active=0
    cur_path=""
    lineno=0
    while IFS= read -r yline || [[ -n "$yline" ]]; do
      lineno=$((lineno + 1))
      if [[ "$yline" == "active_documents:" ]]; then in_active=1; cur_path=""; continue; fi
      if [[ "$yline" == "transitional_rationale:" ]]; then in_active=0; cur_path=""; continue; fi
      if [[ "$yline" == "historical_documents:" ]]; then in_active=0; cur_path=""; continue; fi
      [[ $in_active -eq 0 ]] && continue
      if [[ "$yline" =~ ^[[:space:]]+-[[:space:]]+path:[[:space:]]+(.+)$ ]]; then
        cur_path="${BASH_REMATCH[1]}"
        cur_path="${cur_path%%[[:space:]]*}"
        continue
      fi
      if [[ -n "$cur_path" ]]; then
        for marker in v7_disposition supersedes_to sunset_by; do
          if [[ "$yline" =~ ^[[:space:]]+${marker}: ]]; then
            fail "active_corpus_no_disposition_in_active" "active_documents entry $cur_path has forbidden field '$marker' (cycle-9 A1)" "$active_corpus_path" "$lineno"
          fi
        done
      fi
    done < "$active_corpus_path"
  fi

  # 23. Index active subset (cycle-9 B2): primary hierarchy in
  # current-architecture-index.md must be a subset of active_documents.
  if [[ -f "$index_path" && ${#active_paths[@]} -gt 0 ]]; then
    declare -a active_basenames=()
    for ap in "${active_paths[@]}"; do
      active_basenames+=("$(basename "$ap")")
    done
    # Extract md links from "Active hierarchy" section only -- stop at
    # the very next top-level "## " heading (Governance corpus / Plans
    # / Gates / Delivery / etc are NOT part of the architecture
    # hierarchy and host their own evidence references).
    awk '/^## Active hierarchy/{p=1; next} p && /^## /{p=0} p' "$index_path" > /tmp/_active_section.txt 2>/dev/null || true
    if [[ -f /tmp/_active_section.txt ]]; then
      while IFS= read -r line; do
        # find markdown links of the form (../../path/to/file.md) or (path)
        while [[ "$line" =~ \(([^\)]+\.md)\) ]]; do
          link="${BASH_REMATCH[1]}"
          line="${line/${BASH_REMATCH[0]}/}"
          # normalize: drop ../ prefixes; just check basename
          base=$(basename "$link")
          # skip if any active path basename matches
          found=0
          for ab in "${active_basenames[@]}"; do
            if [[ "$ab" == "$base" ]]; then found=1; break; fi
          done
          # ARCHITECTURE.md occurs many times; treat any active L0/L1/L2 .md as OK if name matches
          if [[ $found -eq 0 ]]; then
            # link could legitimately reference an active path; skip transient files
            case "$base" in
              ARCHITECTURE.md|*.yaml|*.json) found=1 ;;
            esac
          fi
          if [[ $found -eq 0 ]]; then
            fail "index_active_subset" "current-architecture-index.md active hierarchy references non-active path: $link" "$index_path" 0
          fi
        done
      done < /tmp/_active_section.txt
      rm -f /tmp/_active_section.txt
    fi
  fi

  # 21. Rule 8 state consistency (cycle-8 C2).
  rule_8_state=""
  if [[ -f "$manifest_path" ]]; then
    rule_8_state=$(awk '/^rule_8:/{flag=1; next} flag && /^[[:space:]]+state:/ {gsub(/^[[:space:]]+state:[[:space:]]*/,""); print; exit}' "$manifest_path" 2>/dev/null || true)
    rule_8_state="${rule_8_state%% #*}"
    rule_8_state="${rule_8_state%"${rule_8_state##*[![:space:]]}"}"
  fi
  if [[ "$rule_8_state" == "fail_closed_artifact_missing" && -f "$status_path" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^[[:space:]]+maturity:[[:space:]]*L3 ]]; then
        fail "rule_8_state_consistency" "capability declares maturity: L3 while manifest.rule_8.state=fail_closed_artifact_missing" "$status_path" 0
      fi
      if [[ "$line" =~ ^[[:space:]]+maturity:[[:space:]]*L4 ]]; then
        fail "rule_8_state_consistency" "capability declares maturity: L4 while manifest.rule_8.state=fail_closed_artifact_missing" "$status_path" 0
      fi
      if [[ "$line" =~ ^[[:space:]]+(status|evidence_state):[[:space:]]*operator_gated ]]; then
        fail "rule_8_state_consistency" "capability declares operator_gated while manifest.rule_8.state=fail_closed_artifact_missing" "$status_path" 0
      fi
      if [[ "$line" =~ ^[[:space:]]+(status|evidence_state):[[:space:]]*released ]]; then
        fail "rule_8_state_consistency" "capability declares released while manifest.rule_8.state=fail_closed_artifact_missing" "$status_path" 0
      fi
    done < "$status_path"
    # Scan delivery files for Rule 8 PASS claims.
    while IFS= read -r dfile; do
      [[ -z "$dfile" ]] && continue
      if grep -E -q '(Rule 8 PASS|Rule[[:space:]]*8[[:space:]]*PASS)' "$dfile" 2>/dev/null; then
        # Allow phrases that explicitly negate Rule 8 PASS.
        if ! grep -E -q '(NOT Rule 8 PASS|not Rule 8 PASS|fails closed|fail-closed|fail_closed_artifact_missing|FAIL_ARTIFACT_MISSING)' "$dfile" 2>/dev/null; then
          fail "rule_8_state_consistency" "delivery file claims Rule 8 PASS while manifest.rule_8.state=fail_closed_artifact_missing" "$dfile" 0
        fi
      fi
    done < <(find docs/delivery -maxdepth 1 -type f -name '2026-05-08-*.md' 2>/dev/null || true)
  fi

  # 17. Capability legacy-bucket (cycle-7 D2).
  if [[ -f "$status_path" ]]; then
    declare -a buf=()
    while IFS= read -r line || [[ -n "$line" ]]; do buf+=("$line"); done < "$status_path"
    n=${#buf[@]}
    in_findings=0
    for ((i=0; i<n; i++)); do
      line="${buf[i]}"
      if [[ "$line" =~ ^findings: ]]; then in_findings=1; fi
      [[ $in_findings -eq 0 ]] && continue
      if [[ "$line" =~ ^[[:space:]]+capability:[[:space:]]*operator_shape_gate[[:space:]]*$ ]]; then
        has_legacy=0
        lo=$((i - 5)); [[ $lo -lt 0 ]] && lo=0
        hi=$((i + 5)); [[ $hi -ge $n ]] && hi=$((n - 1))
        for ((j=lo; j<=hi; j++)); do
          if [[ "${buf[j]}" =~ ^[[:space:]]+legacy_capability:[[:space:]]*operator_shape_gate ]]; then
            has_legacy=1; break
          fi
        done
        if [[ $has_legacy -eq 0 ]]; then
          fail "capability_legacy_bucket" "finding uses deprecated 'capability: operator_shape_gate' without legacy_capability marker" "$status_path" "$((i+1))"
        fi
      fi
    done
    unset buf
  fi

  # 24. CI no-or-true mask (cycle-14 A1): gate/run_* calls in CI workflows
  # must not be masked with || true. Removes the escape hatch that allowed a
  # failing Rule 8 smoke gate to silently pass CI.
  while IFS= read -r _wf_file; do
    [[ -f "$_wf_file" ]] || continue
    _wf_lineno=0
    while IFS= read -r _wf_line; do
      _wf_lineno=$((_wf_lineno + 1))
      if [[ "$_wf_line" == *"gate/run_"* && "$_wf_line" == *"|| true"* ]]; then
        fail "ci_no_or_true_mask" "CI workflow masks gate/run_* with '|| true' -- remove the mask or rename the step to *_report_only" "$_wf_file" $_wf_lineno
      fi
    done < "$_wf_file"
  done < <(find .github/workflows -maxdepth 1 -name '*.yml' -type f 2>/dev/null || true)

  # 25. Rule 8 state machine coherent (cycle-14 B1): artifact_present_state
  # must agree with rule_8.state. Prevents internally-contradictory manifests.
  if [[ -f "$manifest_path" ]]; then
    _artifact_state=$(awk '/^artifact_present_state:/{gsub(/^artifact_present_state:[[:space:]]*/,""); gsub(/ #.*$/,""); gsub(/[[:space:]]*$/,""); print; exit}' "$manifest_path" 2>/dev/null || true)
    if [[ -n "$_artifact_state" && -n "$rule_8_state" ]]; then
      case "$_artifact_state" in
        none)
          if [[ "$rule_8_state" != "fail_closed_artifact_missing" ]]; then
            fail "rule_8_state_machine_coherent" "artifact_present_state=none but rule_8.state=$rule_8_state (expected fail_closed_artifact_missing)" "$manifest_path" 0
          fi ;;
        source_only)
          if [[ "$rule_8_state" != "fail_closed_needs_build" ]]; then
            fail "rule_8_state_machine_coherent" "artifact_present_state=source_only but rule_8.state=$rule_8_state (expected fail_closed_needs_build)" "$manifest_path" 0
          fi ;;
        jar_present)
          if [[ "$rule_8_state" != "fail_closed_needs_real_flow" && "$rule_8_state" != "pass" ]]; then
            fail "rule_8_state_machine_coherent" "artifact_present_state=jar_present but rule_8.state=$rule_8_state (expected fail_closed_needs_real_flow or pass)" "$manifest_path" 0
          fi ;;
        *)
          fail "rule_8_state_machine_coherent" "artifact_present_state has unknown value: $_artifact_state (valid: none | source_only | jar_present)" "$manifest_path" 0 ;;
      esac
    fi
  fi
  # 26. Contract catalog present (cycle-15/16 D1): docs/contracts/contract-catalog.md
  # must exist. Created in T-CS-Docs; indexes all external contract types.
  _contract_catalog="docs/contracts/contract-catalog.md"
  if [[ ! -f "$_contract_catalog" ]]; then
    fail "contract_catalog_present" "docs/contracts/contract-catalog.md not found; create it per T-CS-Docs" "$_contract_catalog" 0
  fi

  # 27. OpenAPI snapshot pinned (cycle-15/16 D2): docs/contracts/openapi-v1.yaml
  # must exist. Created in T-CS-2; pins the W0 public surface.
  _openapi_yaml="docs/contracts/openapi-v1.yaml"
  if [[ ! -f "$_openapi_yaml" ]]; then
    fail "openapi_snapshot_pinned" "docs/contracts/openapi-v1.yaml not found; create it per T-CS-2" "$_openapi_yaml" 0
  fi

  # 28. Metric naming namespace (cycle-15/16 D3): all .counter("...") calls in
  # Java sources must use the springai_fin_ prefix. Catches namespace drift.
  while IFS= read -r _mf; do
    [[ -f "$_mf" ]] || continue
    while IFS= read -r _ml; do
      if [[ "$_ml" == *'.counter("'* ]]; then
        _n="${_ml#*.counter(\"}"
        _n="${_n%%\"*}"
        if [[ -n "$_n" && "${_n:0:12}" != "springai_fin" ]]; then
          fail "metric_naming_namespace" "Counter name '$_n' does not use springai_fin_ prefix" "$_mf" 0
        fi
      fi
    done < "$_mf"
  done < <(find . -name '*.java' -not -path '*/target/*' -not -path '*/.git/*' 2>/dev/null || true)

} || {
  rule_body_succeeded=false
  runtime_error_message="rule body failed"
  fail "gate_runtime_error" "bash rule body returned non-zero" "" 0
}

# Compute final state.
semantic_fail_count=$((fail_count - dirty_tree_count))
semantic_pass=true
[[ $semantic_fail_count -gt 0 ]] && semantic_pass=false
evidence_valid=true
[[ "${tree_clean:-true}" == "false" ]] && evidence_valid=false
[[ "$semantic_pass" == "false" ]] && evidence_valid=false
[[ $local_only -eq 1 ]] && evidence_valid=false  # cycle-14 A2: local-only runs are never delivery-valid

if [[ "$evidence_valid" == "true" ]]; then
  log_dir="gate/log"
else
  log_dir="gate/log/local"
fi
mkdir -p "$log_dir"
log_path="$log_dir/${sha_candidate}-posix.json"

local_only_json=false
[[ $local_only -eq 1 ]] && local_only_json=true

porcelain_escaped="$(json_escape "${porcelain:-}")"

{
  printf '{'
  printf '"script":"check_architecture_sync.sh",'
  printf '"version":"cycle-9-truth-cut",'
  printf '"platform":"posix",'
  printf '"sha":"%s",' "$sha_candidate"
  printf '"generated":"%s",' "$(date -Iseconds 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '"scan_files_count":%d,' "${#all_scan_files[@]}"
  printf '"working_tree_clean":%s,' "${tree_clean:-true}"
  printf '"git_status_porcelain":"%s",' "$porcelain_escaped"
  printf '"local_only":%s,' "$local_only_json"
  printf '"semantic_pass":%s,' "$semantic_pass"
  printf '"evidence_valid_for_delivery":%s,' "$evidence_valid"
  printf '"rule_body_succeeded":%s,' "$rule_body_succeeded"
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
