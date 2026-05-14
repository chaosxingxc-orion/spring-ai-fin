#!/usr/bin/env bash
# spring-ai-ascend architecture-sync gate -- L1 Rule-28 expansion + Phase K + L1.x Telemetry Vertical + Layer-0 governing principles (47 rules; 36 base + 11 Rule-28 sub-checks).
# Exits 0 if all rules pass, 1 if any fail.
# Each rule prints PASS: <name> or FAIL: <name> -- <reason>.
# Prints GATE: PASS or GATE: FAIL at the end.
#
# Rules:
#   1.  status_enum_invalid                          -- docs/governance/architecture-status.yaml status values
#   2.  delivery_log_parity                          -- gate/log/*.json sha field matches filename basename
#   3.  eol_policy                                   -- *.sh files in gate/ must be LF (not CRLF)
#   4.  ci_no_or_true_mask                           -- no gate/run_* || true in .github/workflows/*.yml
#   5.  required_files_present                       -- contract-catalog.md and openapi-v1.yaml must exist
#   6.  metric_naming_namespace                      -- springai_ascend_ prefix in Java metric names
#   7.  shipped_impl_paths_exist                     -- every shipped: true implementation: path exists on disk
#   8.  no_hardcoded_versions_in_arch                -- module ARCHITECTURE.md files must not pin OSS versions inline
#   9.  openapi_path_consistency                     -- /v3/api-docs must appear in WebSecurityConfig + platform ARCH
#  10.  module_dep_direction                         -- agent-runtime must not depend on agent-platform (ADR-0055: platform->runtime is now ALLOWED)
#  11.  shipped_envelope_fingerprint_present         -- InMemoryCheckpointer enforces §4 #13 16-KiB cap
#  12.  inmemory_orchestrator_posture_guard_present  -- AppPostureGate.requireDev in all 3 in-memory components (ADR-0035)
#  13.  contract_catalog_no_deleted_spi_or_starter_names -- contract-catalog.md must not reference deleted names
#  14.  module_arch_method_name_truth                -- method names in ARCHITECTURE.md code-fences must exist in Java class
#  15.  no_active_refs_deleted_wave_plan_paths        -- active .md files must not reference docs/plans/engineering-plan-W0-W4.md or roadmap-W0-W4.md
#  16.  http_contract_w1_tenant_and_cancel_consistency -- W1 HTTP contract: no replace-X-Tenant-Id wording, no CREATED initial status, no DELETE cancel route
#  17.  contract_catalog_spi_table_matches_source     -- SPI sub-table must list 7 known SPIs; OssApiProbe must not appear before Probes sub-table
#  18.  deleted_spi_starter_names_outside_catalog     -- ACTIVE_NORMATIVE_DOCS corpus must not reference deleted SPI/starter names (widened, ADR-0043)
#  19.  shipped_row_tests_evidence                    -- every shipped: true row must have non-empty tests: pointing to real files (ADR-0042, strengthened)
#  20.  module_metadata_truth                         -- module README.md must not reference Java class names absent from the repo (ADR-0043)
#  21.  bom_glue_paths_exist                          -- BoM must not contain known ghost implementation paths unless they exist (ADR-0043)
#  22.  lowercase_metrics_in_contract_docs            -- ACTIVE_NORMATIVE_DOCS must not contain SPRINGAI_ASCEND_<lowercase> patterns (ADR-0043, widened)
#  23.  active_doc_internal_links_resolve             -- markdown links ](path) in active docs must resolve to existing files (ADR-0043)
#  24.  shipped_row_evidence_paths_exist              -- l2_documents: and latest_delivery_file: on shipped rows must exist on disk (ADR-0045)
#  25.  peripheral_wave_qualifier                     -- SPI Javadoc and active docs must not name future-wave impls without wave qualifier (ADR-0045)
#  26.  release_note_shipped_surface_truth            -- docs/releases/*.md must not overclaim RunLifecycle/RunContext.posture/ApiCompatibilityTest-as-OpenAPI/AppPostureGate-scope (ADR-0046)
#  27.  active_entrypoint_baseline_truth              -- root README.md baseline counts must match architecture-status.yaml.architecture_sync_gate.allowed_claim (ADR-0047)
#  28.  release_note_baseline_truth                   -- docs/releases/*.md baseline counts must match canonical YAML unless marked "Historical artifact frozen at SHA" (ADR-0049, whitepaper-alignment P0-1)
#  29.  whitepaper_alignment_matrix_present           -- docs/governance/whitepaper-alignment-matrix.md must exist and list all 20 required whitepaper concepts (ADR-0049, whitepaper-alignment P2-1)
#  --- L1 Rule-28 sub-checks (ADR-0059) ---
#  28a. tenant_column_present                          -- every CREATE TABLE in db/migration declares tenant_id (enforcer E15)
#  28b. high_cardinality_tag_guard                     -- no Tag.of("run_id"|"idempotency_key"|"jwt_sub"|"body", …) in agent-*/main (enforcer E19)
#  28c. no_secret_patterns                             -- gitleaks-style sweep of tracked files; allowlist via 'secret-allowlist:' (enforcer E20)
#  28d. out_of_scope_name_guard                        -- W2+ deferred names absent from agent-*/main (enforcer E26)
#  28e. module_count_invariant                         -- root pom.xml declares exactly 4 <module> entries (enforcer E27)
#  28f. enforcers_yaml_wellformed                      -- docs/governance/enforcers.yaml every row has all 5 fields + legal kind (enforcer E29)
#  28g. no_prose_only_constraint_marker                -- no TODO/FIXME/XXX/deferred:enforce|enforcer|test|gate in CLAUDE.md / ARCHITECTURE.md (enforcer E30)
#  28h. l1_review_checklist_present                    -- ADRs 0055–0059 contain '§16 Review Checklist' (enforcer E31)
#  28i. plan_enforcer_table_in_sync                    -- plan §11 IDs == enforcers.yaml IDs (enforcer E32)
#  28j. enforcer_artifact_paths_exist                   -- every artifact: path in enforcers.yaml resolves on disk (enforcer E33, Phase K audit fix F6)
#  28.  constraint_enforcer_coverage                   -- enforcers.yaml references CLAUDE.md AND ARCHITECTURE.md (meta-rule, enforcer E28)
#  30.  telemetry_vertical_constraint_coverage         -- ARCHITECTURE.md §4 #53–#59 each cited by an enforcer row (L1.x Telemetry Vertical, enforcer E47)
#  --- Layer-0 governing principles (ADR-0064..0067) ---
#  31.  quickstart_present                              -- docs/quickstart.md present and referenced from README.md (Rule 29, enforcer E49)
#  32.  competitive_baselines_present_and_wellformed    -- docs/governance/competitive-baselines.yaml has 4 pillars (Rule 30, enforcer E50)
#  33.  release_note_references_four_pillars            -- latest release note mentions all 4 pillars by name (Rule 30, enforcer E51)
#  34.  module_metadata_present_and_complete            -- every <module>/pom.xml has a sibling module-metadata.yaml with required keys (Rule 31, enforcer E52)
#  35.  dfx_yaml_present_and_wellformed                 -- every kind:platform|domain module has docs/dfx/<module>.yaml with 5 DFX dimensions (Rule 32, enforcer E53)
#  36.  domain_module_has_spi_package                   -- every kind:domain module declares spi_packages and each one resolves on disk (Rule 32, enforcer E54)

set -uo pipefail
export LC_ALL=C

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fail_count=0

pass_rule() { echo "PASS: $1"; }
fail_rule() {
  echo "FAIL: $1 -- $2"
  fail_count=$((fail_count + 1))
}

# ---------------------------------------------------------------------------
# Rule 1 — status_enum_invalid
# docs/governance/architecture-status.yaml status: values must be in the
# allowed enum. Any other value is a FAIL.
# ---------------------------------------------------------------------------
_status_path="docs/governance/architecture-status.yaml"
_allowed_status_re='^(design_accepted|implemented_unverified|test_verified|deferred_w1|deferred_w2)$'
_r1_fail=0
if [[ -f "$_status_path" ]]; then
  while IFS= read -r _line || [[ -n "$_line" ]]; do
    _val=$(printf '%s\n' "$_line" | sed -nE 's/^[[:space:]]*status:[[:space:]]*([A-Za-z_]+)[[:space:]]*$/\1/p')
    if [[ -n "$_val" ]] && ! [[ "$_val" =~ $_allowed_status_re ]]; then
      fail_rule "status_enum_invalid" "status '$_val' not in allowed enum {design_accepted,implemented_unverified,test_verified,deferred_w1,deferred_w2} in $_status_path"
      _r1_fail=1
      break
    fi
  done < "$_status_path"
  if [[ $_r1_fail -eq 0 ]]; then pass_rule "status_enum_invalid"; fi
else
  fail_rule "status_enum_invalid" "$_status_path not found"
fi

# ---------------------------------------------------------------------------
# Rule 2 — delivery_log_parity
# For each gate/log/*.json file: its sha field must equal the basename
# (without .json suffix). Its semantic_pass field must be a boolean.
# ---------------------------------------------------------------------------
_r2_fail=0
_r2_checked=0
while IFS= read -r _lf; do
  [[ -z "$_lf" ]] && continue
  _base="$(basename "$_lf" .json)"
  # Strip platform suffix (-posix, -windows) to get the sha
  _sha="${_base%%-posix}"
  _sha="${_sha%%-windows}"
  # Skip non-sha filenames (self-test-*, operator-shape-*, etc.)
  if [[ "$_sha" == self-test-* ]] || [[ "$_sha" == operator-shape-* ]]; then continue; fi
  _r2_checked=$((_r2_checked + 1))
  _log_sha="$(grep -oE '"sha":"[^"]*"' "$_lf" 2>/dev/null | head -1 | sed -E 's/.*"sha":"([^"]*)".*/\1/')"
  if [[ "$_log_sha" != "$_sha" ]]; then
    fail_rule "delivery_log_parity" "log $(basename "$_lf"): sha field '$_log_sha' != filename sha '$_sha'"
    _r2_fail=1
    break
  fi
  _sem="$(grep -oE '"semantic_pass":(true|false)' "$_lf" 2>/dev/null | head -1 | sed -E 's/.*:(.*)/\1/')"
  if [[ -z "$_sem" ]]; then
    fail_rule "delivery_log_parity" "log $(basename "$_lf") missing semantic_pass boolean field"
    _r2_fail=1
    break
  fi
done < <(find gate/log -maxdepth 1 -name '*.json' -type f 2>/dev/null | sort || true)
if [[ $_r2_fail -eq 0 ]]; then pass_rule "delivery_log_parity"; fi

# ---------------------------------------------------------------------------
# Rule 3 — eol_policy
# All *.sh files in gate/ must have LF line endings (not CRLF).
# ---------------------------------------------------------------------------
_r3_fail=0
while IFS= read -r _shf; do
  [[ -z "$_shf" ]] && continue
  [[ ! -f "$_shf" ]] && continue
  if grep -qU $'\r' "$_shf" 2>/dev/null; then
    fail_rule "eol_policy" "$_shf contains CRLF; must be LF"
    _r3_fail=1
    break
  fi
done < <(find gate -maxdepth 1 -name '*.sh' -type f 2>/dev/null | sort || true)
if [[ $_r3_fail -eq 0 ]]; then pass_rule "eol_policy"; fi

# ---------------------------------------------------------------------------
# Rule 4 — ci_no_or_true_mask
# .github/workflows/*.yml files must not contain gate/run_* invocations
# masked with || true.
# ---------------------------------------------------------------------------
_r4_fail=0
while IFS= read -r _wf; do
  [[ -f "$_wf" ]] || continue
  if grep -qE 'gate/run_.*\|\|[[:space:]]*true' "$_wf" 2>/dev/null; then
    fail_rule "ci_no_or_true_mask" "$_wf contains gate/run_* masked with || true"
    _r4_fail=1
    break
  fi
done < <(find .github/workflows -maxdepth 1 -name '*.yml' -type f 2>/dev/null | sort || true)
if [[ $_r4_fail -eq 0 ]]; then pass_rule "ci_no_or_true_mask"; fi

# ---------------------------------------------------------------------------
# Rule 5 — required_files_present
# These 2 files must exist: docs/contracts/contract-catalog.md and
# docs/contracts/openapi-v1.yaml.
# ---------------------------------------------------------------------------
_r5_fail=0
for _req in "docs/contracts/contract-catalog.md" "docs/contracts/openapi-v1.yaml"; do
  if [[ ! -f "$_req" ]]; then
    fail_rule "required_files_present" "$_req not found"
    _r5_fail=1
  fi
done
if [[ $_r5_fail -eq 0 ]]; then pass_rule "required_files_present"; fi

# ---------------------------------------------------------------------------
# Rule 6 — metric_naming_namespace
# In *.java files under agent-platform/src and agent-runtime/src, any
# hardcoded metric name strings must start with springai_ascend_.
# Also no springai_fin_ prefix outside docs/archive/.
# ---------------------------------------------------------------------------
_r6_fail=0
while IFS= read -r _jf; do
  [[ -f "$_jf" ]] || continue
  while IFS= read -r _jl; do
    # Match .counter("name") or similar metric-name string literals
    _nm="${_jl#*.counter(\"}"
    if [[ "$_nm" != "$_jl" ]]; then
      _nm="${_nm%%\"*}"
      if [[ -n "$_nm" && "${_nm:0:15}" != "springai_ascend" ]]; then
        fail_rule "metric_naming_namespace" "counter name '$_nm' in $_jf does not use springai_ascend_ prefix"
        _r6_fail=1
        break 2
      fi
    fi
    # Also catch timer/gauge builders if needed: .timer("name") .gauge("name")
    for _mbuilder in "timer" "gauge" "summary"; do
      _nm2="${_jl#*.$_mbuilder(\"}"
      if [[ "$_nm2" != "$_jl" ]]; then
        _nm2="${_nm2%%\"*}"
        if [[ -n "$_nm2" && "${_nm2:0:15}" != "springai_ascend" ]]; then
          fail_rule "metric_naming_namespace" "$_mbuilder name '$_nm2' in $_jf does not use springai_ascend_ prefix"
          _r6_fail=1
          break 3
        fi
      fi
    done
  done < "$_jf"
done < <(find agent-platform/src agent-runtime/src -name '*.java' 2>/dev/null | sort || true)
# Check for residual springai_fin_ prefix outside docs/archive/
if grep -rn 'springai_fin_\|springai\.fin\.' \
    --include='*.java' \
    agent-platform/src agent-runtime/src \
    2>/dev/null | grep -qv 'docs/archive'; then
  fail_rule "metric_naming_namespace" "residual springai_fin_ or springai.fin. found in Java sources"
  _r6_fail=1
fi
if [[ $_r6_fail -eq 0 ]]; then pass_rule "metric_naming_namespace"; fi

# ---------------------------------------------------------------------------
# Rule 7 — shipped_impl_paths_exist
# Every capability row with shipped: true in architecture-status.yaml MUST
# have all its implementation: paths exist on disk.
# ---------------------------------------------------------------------------
_r7_fail=0
_status_file='docs/governance/architecture-status.yaml'
_in_shipped=0
_current_impl=''
if [[ -f "$_status_file" ]]; then
  while IFS= read -r _line; do
    if echo "$_line" | grep -qE '^\s*shipped:\s*true'; then
      _in_shipped=1
    elif echo "$_line" | grep -qE '^\s*shipped:\s*false'; then
      _in_shipped=0
    elif [[ $_in_shipped -eq 1 ]] && echo "$_line" | grep -qE '^\s*-\s+\S'; then
      _impl_path=$(echo "$_line" | sed -E 's/^\s*-\s+//')
      if [[ -n "$_impl_path" ]] && [[ "$_impl_path" != "null" ]]; then
        if [[ ! -e "$_impl_path" ]]; then
          fail_rule "shipped_impl_paths_exist" "shipped: true row references non-existent path: $_impl_path"
          _r7_fail=1
        fi
      fi
    elif echo "$_line" | grep -qE '^\s*(status|tests|allowed_claim|l0_decision|l2_documents|note):'; then
      _in_shipped=0
    fi
  done < "$_status_file"
fi
if [[ $_r7_fail -eq 0 ]]; then pass_rule "shipped_impl_paths_exist"; fi

# ---------------------------------------------------------------------------
# Rule 8 — no_hardcoded_versions_in_arch
# module ARCHITECTURE.md files (agent-platform/, agent-runtime/) must not
# pin OSS versions inline (e.g., "Spring Boot 3.2.1" or "Java 21.0.2").
# ---------------------------------------------------------------------------
_r8_fail=0
for _arch in 'agent-platform/ARCHITECTURE.md' 'agent-runtime/ARCHITECTURE.md'; do
  if [[ -f "$_arch" ]]; then
    if grep -qE '[0-9]+\.[0-9]+\.[0-9]+' "$_arch" 2>/dev/null; then
      fail_rule "no_hardcoded_versions_in_arch" "$_arch contains inline version pin (x.y.z pattern). Move version pins to pom.xml or oss-bill-of-materials.md."
      _r8_fail=1
    fi
  fi
done
if [[ $_r8_fail -eq 0 ]]; then pass_rule "no_hardcoded_versions_in_arch"; fi

# ---------------------------------------------------------------------------
# Rule 9 — openapi_path_consistency
# /v3/api-docs must appear in the agent-platform ARCHITECTURE.md documenting
# the security permit path.
# ---------------------------------------------------------------------------
_r9_fail=0
_plat_arch='agent-platform/ARCHITECTURE.md'
if [[ -f "$_plat_arch" ]]; then
  if ! grep -q '/v3/api-docs' "$_plat_arch" 2>/dev/null; then
    fail_rule "openapi_path_consistency" "$_plat_arch does not document /v3/api-docs exposure. Document it or remove the security permitAll."
    _r9_fail=1
  fi
fi
if [[ $_r9_fail -eq 0 ]]; then pass_rule "openapi_path_consistency"; fi

# ---------------------------------------------------------------------------
# Rule 10 — module_dep_direction (amended at L1 by ADR-0055)
# agent-runtime/pom.xml must NOT declare a dependency on agent-platform.
# (agent-platform -> agent-runtime is now ALLOWED per ADR-0055 for the W1
# HTTP run handoff. The reverse direction stays forbidden at pom level here
# and at source level via RuntimeMustNotDependOnPlatformTest, enforcer E2.)
# Enforcer row: docs/governance/enforcers.yaml#E1
# ---------------------------------------------------------------------------
_r10_fail=0
if [[ -f 'agent-runtime/pom.xml' ]]; then
  if grep -q '<artifactId>agent-platform</artifactId>' 'agent-runtime/pom.xml' 2>/dev/null; then
    fail_rule "module_dep_direction" "agent-runtime/pom.xml declares dependency on agent-platform. Per ADR-0055 forbidden (runtime must not depend on platform)."
    _r10_fail=1
  fi
fi
if [[ $_r10_fail -eq 0 ]]; then pass_rule "module_dep_direction"; fi

# ---------------------------------------------------------------------------
# Rule 11 — shipped_envelope_fingerprint_present
# InMemoryCheckpointer.java MUST contain MAX_INLINE_PAYLOAD_BYTES to prove
# the §4 #13 16-KiB inline cap is actually enforced (not just documented).
# ---------------------------------------------------------------------------
_r11_fail=0
_imc_path='agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryCheckpointer.java'
if [[ -f "$_imc_path" ]]; then
  if ! grep -q 'MAX_INLINE_PAYLOAD_BYTES' "$_imc_path" 2>/dev/null; then
    fail_rule "shipped_envelope_fingerprint_present" "$_imc_path missing MAX_INLINE_PAYLOAD_BYTES. §4 #13 16-KiB cap enforcement required."
    _r11_fail=1
  fi
else
  fail_rule "shipped_envelope_fingerprint_present" "$_imc_path not found on disk"
  _r11_fail=1
fi
if [[ $_r11_fail -eq 0 ]]; then pass_rule "shipped_envelope_fingerprint_present"; fi

# ---------------------------------------------------------------------------
# Rule 12 — inmemory_orchestrator_posture_guard_present
# ADR-0035: AppPostureGate.requireDevForInMemoryComponent is the single
# construction path for posture reads. All three in-memory components MUST
# contain AppPostureGate.requireDev in their source.
# ---------------------------------------------------------------------------
_r12_fail=0
_posture_targets=(
  'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java'
  'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryRunRegistry.java'
  'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryCheckpointer.java'
)
for _pt in "${_posture_targets[@]}"; do
  if [[ -f "$_pt" ]]; then
    if ! grep -q 'AppPostureGate\.requireDev' "$_pt" 2>/dev/null; then
      fail_rule "inmemory_orchestrator_posture_guard_present" "$_pt does not call AppPostureGate.requireDev*. Per ADR-0035 all in-memory components must delegate posture reads to AppPostureGate."
      _r12_fail=1
    fi
  else
    fail_rule "inmemory_orchestrator_posture_guard_present" "$_pt not found on disk."
    _r12_fail=1
  fi
done
if [[ $_r12_fail -eq 0 ]]; then pass_rule "inmemory_orchestrator_posture_guard_present"; fi

# ---------------------------------------------------------------------------
# Rule 13 — contract_catalog_no_deleted_spi_or_starter_names
# ADR-0036: contract-catalog.md must not reference deleted SPI interface names
# or deleted starter artifact coordinates.
# ---------------------------------------------------------------------------
_r13_fail=0
_catalog='docs/contracts/contract-catalog.md'
_deleted_names=(
  'LongTermMemoryRepository'
  'ToolProvider'
  'LayoutParser'
  'DocumentSourceConnector'
  'PolicyEvaluator'
  'IdempotencyRepository'
  'ArtifactRepository'
  'spring-ai-ascend-memory-starter'
  'spring-ai-ascend-skills-starter'
  'spring-ai-ascend-knowledge-starter'
  'spring-ai-ascend-governance-starter'
  'spring-ai-ascend-persistence-starter'
  'spring-ai-ascend-resilience-starter'
  'spring-ai-ascend-mem0-starter'
  'spring-ai-ascend-docling-starter'
  'spring-ai-ascend-langchain4j-profile'
)
if [[ -f "$_catalog" ]]; then
  for _dn in "${_deleted_names[@]}"; do
    if grep -qF "$_dn" "$_catalog" 2>/dev/null; then
      fail_rule "contract_catalog_no_deleted_spi_or_starter_names" "$_catalog references deleted name '$_dn'. Per ADR-0036 Gate Rule 13 this is a contract-surface truth violation."
      _r13_fail=1
    fi
  done
else
  fail_rule "contract_catalog_no_deleted_spi_or_starter_names" "$_catalog not found."
  _r13_fail=1
fi
if [[ $_r13_fail -eq 0 ]]; then pass_rule "contract_catalog_no_deleted_spi_or_starter_names"; fi

# ---------------------------------------------------------------------------
# Rule 14 — module_arch_method_name_truth
# ADR-0036: method names in code-fence blocks in agent-platform/ARCHITECTURE.md
# and agent-runtime/ARCHITECTURE.md must exist in the named Java class.
# Currently checks the specific known drift: probe.check() was wrong; correct
# is probe.probe(). Fails if probe.check() appears in any module ARCHITECTURE.md.
# ---------------------------------------------------------------------------
_r14_fail=0
for _maf in 'agent-platform/ARCHITECTURE.md' 'agent-runtime/ARCHITECTURE.md'; do
  if [[ -f "$_maf" ]]; then
    if grep -q 'probe\.check()' "$_maf" 2>/dev/null; then
      fail_rule "module_arch_method_name_truth" "$_maf references probe.check() but actual method in OssApiProbe is probe.probe(). Per ADR-0036 Gate Rule 14 method names in docs must match source."
      _r14_fail=1
    fi
  fi
done
if [[ $_r14_fail -eq 0 ]]; then pass_rule "module_arch_method_name_truth"; fi

# ---------------------------------------------------------------------------
# Rule 15 — no_active_refs_deleted_wave_plan_paths
# ADR-0041: active .md files (outside archive/reviews/third_party/target/.git)
# must not reference docs/plans/engineering-plan-W0-W4.md or
# docs/plans/roadmap-W0-W4.md. Both plans were archived per ADR-0037.
# ---------------------------------------------------------------------------
_r15_fail=0
_deleted_plan_refs=('docs/plans/engineering-plan-W0-W4.md' 'docs/plans/roadmap-W0-W4.md')
while IFS= read -r _mdf15; do
  [[ -z "$_mdf15" ]] && continue
  for _ref15 in "${_deleted_plan_refs[@]}"; do
    if grep -qF "$_ref15" "$_mdf15" 2>/dev/null; then
      fail_rule "no_active_refs_deleted_wave_plan_paths" "$_mdf15 references deleted plan path '$_ref15'. Per ADR-0041 Gate Rule 15 active docs must not reference archived plan paths."
      _r15_fail=1
      break 2
    fi
  done
done < <(find . -name '*.md' \
  ! -path './docs/archive/*' \
  ! -path './docs/reviews/*' \
  ! -path './docs/adr/*' \
  ! -path './docs/delivery/*' \
  ! -path './docs/v6-rationale/*' \
  ! -path './third_party/*' \
  ! -path './target/*' \
  ! -path './.git/*' \
  -type f 2>/dev/null | sort || true)
if [[ $_r15_fail -eq 0 ]]; then pass_rule "no_active_refs_deleted_wave_plan_paths"; fi

# ---------------------------------------------------------------------------
# Rule 16 — http_contract_w1_tenant_and_cancel_consistency
# ADR-0040: (a) no "replace.*X-Tenant-Id" in active docs; (b) http-api-contracts.md
# must not reference CREATED as initial status; (c) openapi-v1.yaml must not
# mention DELETE /v1/runs/{runId} as the cancel mechanism.
# ---------------------------------------------------------------------------
_r16_fail=0
# 16a: no forward-looking "will replace X-Tenant-Id" claim in active normative docs
# Exclude docs/adr/: ADRs may legitimately document rejected options and past wrong text.
while IFS= read -r _mdf16; do
  [[ -z "$_mdf16" ]] && continue
  if grep -qE 'TenantContextFilter[[:space:]]+(switches[[:space:]]+to|replaces?([[:space:]]+with)?[[:space:]]+JWT|moves[[:space:]]+to)[[:space:]]+JWT|will[[:space:]]+replace.*X-Tenant-Id|replace[[:space:]]+header-based.*with[[:space:]]+JWT|W1[[:space:]]+replaces.*X-Tenant-Id' "$_mdf16" 2>/dev/null; then
    fail_rule "http_contract_w1_tenant_and_cancel_consistency" "$_mdf16 contains a replacement-implying claim about X-Tenant-Id or TenantContextFilter. Per ADR-0040 W1 adds JWT cross-check; X-Tenant-Id is NOT replaced. Forbidden phrasings: 'switches to JWT', 'replaces with JWT', 'moves to JWT', 'will replace X-Tenant-Id'."
    _r16_fail=1
    break
  fi
done < <(find . -name '*.md' \
  ! -path './docs/archive/*' \
  ! -path './docs/reviews/*' \
  ! -path './docs/adr/*' \
  ! -path './third_party/*' \
  ! -path './target/*' \
  ! -path './.git/*' \
  -type f 2>/dev/null | sort || true)
# 16b: http-api-contracts.md must not say CREATED as initial status
if [[ $_r16_fail -eq 0 ]] && [[ -f 'docs/contracts/http-api-contracts.md' ]]; then
  if grep -qE 'starts in CREATED|CREATED stage|status.*CREATED' 'docs/contracts/http-api-contracts.md' 2>/dev/null; then
    fail_rule "http_contract_w1_tenant_and_cancel_consistency" "docs/contracts/http-api-contracts.md references CREATED as initial run status. Per ADR-0040 initial status is PENDING."
    _r16_fail=1
  fi
fi
# 16c: openapi-v1.yaml must not mention DELETE /v1/runs/{runId} as cancel
if [[ $_r16_fail -eq 0 ]] && [[ -f 'docs/contracts/openapi-v1.yaml' ]]; then
  if grep -qE 'DELETE[[:space:]]*/v1/runs/\{runId\}|DELETE.*runId.*cancel' 'docs/contracts/openapi-v1.yaml' 2>/dev/null; then
    fail_rule "http_contract_w1_tenant_and_cancel_consistency" "docs/contracts/openapi-v1.yaml references DELETE /v1/runs/{runId} as cancel. Per ADR-0040 cancel is POST /v1/runs/{id}/cancel."
    _r16_fail=1
  fi
fi
if [[ $_r16_fail -eq 0 ]]; then pass_rule "http_contract_w1_tenant_and_cancel_consistency"; fi

# ---------------------------------------------------------------------------
# Rule 17 — contract_catalog_spi_table_matches_source
# ADR-0041: contract-catalog.md must list the 7 known active SPI interfaces.
# OssApiProbe must NOT appear before the **Probes sub-table heading.
# ---------------------------------------------------------------------------
_r17_fail=0
_catalog17='docs/contracts/contract-catalog.md'
_known_spis=('RunRepository' 'Checkpointer' 'GraphMemoryRepository' 'ResilienceContract' 'Orchestrator' 'GraphExecutor' 'AgentLoopExecutor')
if [[ -f "$_catalog17" ]]; then
  for _spi in "${_known_spis[@]}"; do
    if ! grep -qF "$_spi" "$_catalog17" 2>/dev/null; then
      fail_rule "contract_catalog_spi_table_matches_source" "$_catalog17 does not list SPI '$_spi'. Per ADR-0041 Gate Rule 17 all 7 active SPI interfaces must appear."
      _r17_fail=1
    fi
  done
  if [[ $_r17_fail -eq 0 ]]; then
    _past_probes=0
    while IFS= read -r _ln17; do
      if echo "$_ln17" | grep -qE '\*\*Probes|^#+[[:space:]]+Probes'; then _past_probes=1; fi
      if [[ $_past_probes -eq 0 ]] && echo "$_ln17" | grep -qF 'OssApiProbe'; then
        fail_rule "contract_catalog_spi_table_matches_source" "$_catalog17 contains OssApiProbe before the Probes sub-table. OssApiProbe is a probe, not an SPI. Per ADR-0041 Gate Rule 17."
        _r17_fail=1
        break
      fi
    done < "$_catalog17"
  fi
  # ADR-0044 extension: RunContext row in data-carriers sub-table must contain 'interface'
  if [[ $_r17_fail -eq 0 ]]; then
    _in_data_carriers=0
    _run_ctx_has_interface=0
    _run_ctx_found=0
    while IFS= read -r _ln17x; do
      if echo "$_ln17x" | grep -qE '\*\*Data carriers'; then _in_data_carriers=1; fi
      if [[ $_in_data_carriers -eq 1 ]] && echo "$_ln17x" | grep -qF 'RunContext'; then
        _run_ctx_found=1
        if echo "$_ln17x" | grep -qF 'interface'; then _run_ctx_has_interface=1; fi
        break
      fi
    done < "$_catalog17"
    if [[ $_run_ctx_found -eq 1 && $_run_ctx_has_interface -eq 0 ]]; then
      fail_rule "contract_catalog_spi_table_matches_source" "$_catalog17 RunContext row in data-carriers sub-table does not contain 'interface'. Per ADR-0044 Gate Rule 17 extension RunContext must be classified as interface."
      _r17_fail=1
    fi
  fi
else
  fail_rule "contract_catalog_spi_table_matches_source" "$_catalog17 not found."
  _r17_fail=1
fi
if [[ $_r17_fail -eq 0 ]]; then pass_rule "contract_catalog_spi_table_matches_source"; fi

# ---------------------------------------------------------------------------
# Rule 18 — deleted_spi_starter_names_outside_catalog
# ADR-0041 extends Rule 13: deleted SPI/starter names must not appear in
# third_party/MANIFEST.md, docs/cross-cutting/oss-bill-of-materials.md, README.md.
# ---------------------------------------------------------------------------
_r18_fail=0
_deleted_names18=(
  'LongTermMemoryRepository' 'ToolProvider' 'LayoutParser' 'DocumentSourceConnector'
  'PolicyEvaluator' 'IdempotencyRepository' 'ArtifactRepository'
  'spring-ai-ascend-memory-starter' 'spring-ai-ascend-skills-starter'
  'spring-ai-ascend-knowledge-starter' 'spring-ai-ascend-governance-starter'
  'spring-ai-ascend-persistence-starter' 'spring-ai-ascend-resilience-starter'
  'spring-ai-ascend-mem0-starter' 'spring-ai-ascend-docling-starter'
  'spring-ai-ascend-langchain4j-profile'
)
# Widened to full ACTIVE_NORMATIVE_DOCS corpus (ADR-0043)
while IFS= read -r _t18; do
  [[ -z "$_t18" ]] && continue
  for _dn18 in "${_deleted_names18[@]}"; do
    if grep -qF "$_dn18" "$_t18" 2>/dev/null; then
      fail_rule "deleted_spi_starter_names_outside_catalog" "$_t18 references deleted name '$_dn18'. Per ADR-0043 Gate Rule 18 (widened) this is a contract-surface truth violation."
      _r18_fail=1
    fi
  done
done < <(find . -name '*.md' -o -name '*.yaml' | grep -v '/docs/archive/' | grep -v '/docs/reviews/' | \
  grep -v '/docs/adr/' | grep -v '/docs/delivery/' | grep -v '/docs/v6-rationale/' | \
  grep -v '/docs/plans/' | grep -v '/third_party/' | grep -v '/target/' | grep -v '/.git/' | sort 2>/dev/null || true)
if [[ $_r18_fail -eq 0 ]]; then pass_rule "deleted_spi_starter_names_outside_catalog"; fi

# ---------------------------------------------------------------------------
# Rule 19 — shipped_row_tests_evidence (strengthened per ADR-0042 + ADR-0045)
# Every shipped: true row must have:
#   (a) tests: key present (not absent),
#   (b) tests: non-empty (not [] and not block-empty),
#   (c) every listed test path exists on disk.
# Uses [[:space:]] instead of \s for POSIX portability.
# ---------------------------------------------------------------------------
_r19_fail=0
_current_key19=''
_in_shipped19=0
_in_tests_list19=0
_tests_found19=0
_tests_has_items19=0
_current_test_paths19=()

_flush_shipped19() {
  if [[ $_in_shipped19 -eq 1 ]]; then
    if [[ $_tests_found19 -eq 0 ]]; then
      fail_rule "shipped_row_tests_evidence" "$_status_path capability '$_current_key19' shipped:true but tests: key absent. Per ADR-0042 Gate Rule 19 all shipped rows must have non-empty test evidence."
      _r19_fail=1
    elif [[ $_tests_has_items19 -eq 0 ]]; then
      fail_rule "shipped_row_tests_evidence" "$_status_path capability '$_current_key19' shipped:true but tests: is empty. Per ADR-0042 Gate Rule 19 all shipped rows must have non-empty test evidence."
      _r19_fail=1
    else
      for _tp19 in "${_current_test_paths19[@]}"; do
        if [[ ! -e "$_tp19" ]]; then
          fail_rule "shipped_row_tests_evidence" "$_status_path capability '$_current_key19' lists test path '$_tp19' not found on disk. Per ADR-0042 Gate Rule 19 all test paths must resolve."
          _r19_fail=1
        fi
      done
    fi
  fi
}

while IFS= read -r _line19 || [[ -n "$_line19" ]]; do
  if printf '%s\n' "$_line19" | grep -qE '^  [a-zA-Z][a-zA-Z_]+:'; then
    _flush_shipped19
    _current_key19=$(printf '%s\n' "$_line19" | sed 's/^  \([a-zA-Z][a-zA-Z_]*\):.*/\1/')
    _in_shipped19=0; _in_tests_list19=0
    _tests_found19=0; _tests_has_items19=0; _current_test_paths19=()
    continue
  fi
  if printf '%s\n' "$_line19" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_shipped19=1; fi
  if [[ $_in_shipped19 -eq 1 ]]; then
    if printf '%s\n' "$_line19" | grep -qE '^[[:space:]]+tests:[[:space:]]*\[\]'; then
      _tests_found19=1; _in_tests_list19=0
    elif printf '%s\n' "$_line19" | grep -qE '^[[:space:]]+tests:[[:space:]]*$'; then
      _tests_found19=1; _in_tests_list19=1
    elif printf '%s\n' "$_line19" | grep -qE '^[[:space:]]+tests:'; then
      _tests_found19=1; _in_tests_list19=0
    elif [[ $_in_tests_list19 -eq 1 ]] && printf '%s\n' "$_line19" | grep -qE '^[[:space:]]+-[[:space:]]+'; then
      _tests_has_items19=1
      _tp19_val=$(printf '%s\n' "$_line19" | sed -E 's/^[[:space:]]+-[[:space:]]+(.*)/\1/')
      _current_test_paths19+=("$_tp19_val")
    elif [[ $_in_tests_list19 -eq 1 ]] && ! printf '%s\n' "$_line19" | grep -qE '^[[:space:]]+-'; then
      _in_tests_list19=0
    fi
  fi
done < "$_status_path"
_flush_shipped19
if [[ $_r19_fail -eq 0 ]]; then pass_rule "shipped_row_tests_evidence"; fi

# ---------------------------------------------------------------------------
# Rule 20 — module_metadata_truth
# ADR-0043: module README.md files must not reference Java class names that
# do not exist in the repository.
# ---------------------------------------------------------------------------
_r20_fail=0
_ghost_classes20=('GraphitiRestGraphMemoryRepository' 'CogneeGraphMemoryRepository')
while IFS= read -r _rm20; do
  [[ -z "$_rm20" ]] && continue
  for _gc20 in "${_ghost_classes20[@]}"; do
    if grep -qF "$_gc20" "$_rm20" 2>/dev/null; then
      if ! find . -name "${_gc20}.java" -not -path './target/*' -not -path './.git/*' | grep -q .; then
        fail_rule "module_metadata_truth" "$_rm20 references class '$_gc20' but no .java file exists. Per ADR-0043 Gate Rule 20 module READMEs must not reference non-existent Java classes."
        _r20_fail=1
      fi
    fi
  done
done < <(find . -name 'README.md' ! -path './docs/*' ! -path './third_party/*' ! -path './target/*' 2>/dev/null | sort || true)
if [[ $_r20_fail -eq 0 ]]; then pass_rule "module_metadata_truth"; fi

# ---------------------------------------------------------------------------
# Rule 21 — bom_glue_paths_exist
# ADR-0043: docs/cross-cutting/oss-bill-of-materials.md must not contain the
# known ghost implementation paths unless the path exists on disk.
# ---------------------------------------------------------------------------
_r21_fail=0
_bom21='docs/cross-cutting/oss-bill-of-materials.md'
_ghost_paths21=(
  'agent-runtime/llm/ChatClientFactory' 'agent-runtime/llm/LlmRouter'
  'agent-runtime/memory/PgVectorAdapter' 'agent-runtime/temporal/RunWorkflow'
  'agent-runtime/tool/McpToolRegistry'
)
if [[ -f "$_bom21" ]]; then
  for _gp21 in "${_ghost_paths21[@]}"; do
    if grep -qF "$_gp21" "$_bom21" 2>/dev/null; then
      if [[ ! -e "$_gp21" ]]; then
        fail_rule "bom_glue_paths_exist" "$_bom21 references path '$_gp21' which does not exist on disk. Per ADR-0043 Gate Rule 21 BoM glue paths must exist or be removed."
        _r21_fail=1
      fi
    fi
  done
fi
if [[ $_r21_fail -eq 0 ]]; then pass_rule "bom_glue_paths_exist"; fi

# ---------------------------------------------------------------------------
# Rule 22 — lowercase_metrics_in_contract_docs (widened per ADR-0043/ADR-0045)
# The full ACTIVE_NORMATIVE_DOCS corpus must not contain SPRINGAI_ASCEND_<lowercase>
# metric name patterns. grep -E is case-sensitive by default (LC_ALL=C set above).
# ---------------------------------------------------------------------------
_r22_fail=0
while IFS= read -r _af22; do
  [[ -z "$_af22" ]] && continue
  if grep -qE 'SPRINGAI_ASCEND_[a-z]' "$_af22" 2>/dev/null; then
    fail_rule "lowercase_metrics_in_contract_docs" "$_af22 contains uppercase metric namespace 'SPRINGAI_ASCEND_<lowercase>'. Per ADR-0043 Gate Rule 22 (widened) metric names must use lowercase springai_ascend_ prefix."
    _r22_fail=1
  fi
done < <(find . -name '*.md' -o -name '*.yaml' | grep -v '/docs/archive/' | grep -v '/docs/reviews/' | \
  grep -v '/docs/adr/' | grep -v '/docs/delivery/' | grep -v '/docs/v6-rationale/' | \
  grep -v '/docs/plans/' | grep -v '/third_party/' | grep -v '/target/' | grep -v '/.git/' | sort 2>/dev/null || true)
if [[ $_r22_fail -eq 0 ]]; then pass_rule "lowercase_metrics_in_contract_docs"; fi

# ---------------------------------------------------------------------------
# Rule 23 — active_doc_internal_links_resolve
# ADR-0043: markdown links ](relative-path) in active normative docs must
# resolve to files that exist on disk. Excludes http://, https://, anchors.
# ---------------------------------------------------------------------------
_r23_fail=0
while IFS= read -r _af23; do
  [[ -z "$_af23" ]] && continue
  _dir23="$(dirname "$_af23")"
  while IFS= read -r _link23; do
    [[ -z "$_link23" ]] && continue
    # Strip anchor fragment
    _path23="${_link23%%#*}"
    [[ -z "$_path23" ]] && continue
    # Skip external and anchor-only links
    case "$_link23" in http://*|https://*|mailto:*|'#'*) continue ;; esac
    _resolved23="$(cd "$_dir23" 2>/dev/null && realpath -m "$_path23" 2>/dev/null || echo '')"
    if [[ -n "$_resolved23" && ! -e "$_resolved23" ]]; then
      fail_rule "active_doc_internal_links_resolve" "$_af23 has broken link to '$_link23' (resolved: '$_resolved23'). Per ADR-0043 Gate Rule 23 all internal links in active docs must resolve."
      _r23_fail=1
    fi
  done < <(grep -oE '\]\([^)]+\)' "$_af23" 2>/dev/null | sed 's/^](//;s/)$//' || true)
done < <(find . -name '*.md' \
  ! -path './docs/archive/*' ! -path './docs/reviews/*' \
  ! -path './docs/adr/*' ! -path './docs/delivery/*' \
  ! -path './docs/v6-rationale/*' ! -path './docs/plans/*' \
  ! -path './third_party/*' ! -path './target/*' \
  ! -path './.git/*' \
  -type f 2>/dev/null | sort || true)
if [[ $_r23_fail -eq 0 ]]; then pass_rule "active_doc_internal_links_resolve"; fi

# ---------------------------------------------------------------------------
# Rule 24 — shipped_row_evidence_paths_exist
# ADR-0045: every l2_documents: entry and latest_delivery_file: value on a
# shipped: true row must resolve to an existing file. Closes REF-DRIFT.
# ---------------------------------------------------------------------------
_r24_fail=0
_current_key24=''
_in_shipped24=0
_in_l2_list24=0
while IFS= read -r _line24 || [[ -n "$_line24" ]]; do
  if printf '%s\n' "$_line24" | grep -qE '^  [a-zA-Z][a-zA-Z_]+:'; then
    _current_key24=$(printf '%s\n' "$_line24" | sed 's/^  \([a-zA-Z][a-zA-Z_]*\):.*/\1/')
    _in_shipped24=0; _in_l2_list24=0
    continue
  fi
  if printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+shipped:[[:space:]]+true'; then _in_shipped24=1; fi
  if [[ $_in_shipped24 -eq 1 ]]; then
    # latest_delivery_file
    if printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+latest_delivery_file:[[:space:]]+'; then
      _ldf24=$(printf '%s\n' "$_line24" | sed -E 's/^[[:space:]]+latest_delivery_file:[[:space:]]+(.*)/\1/')
      if [[ -n "$_ldf24" && ! -e "$_ldf24" ]]; then
        fail_rule "shipped_row_evidence_paths_exist" "$_status_path capability '$_current_key24' latest_delivery_file '$_ldf24' not found on disk. Per ADR-0045 Gate Rule 24 all shipped-row evidence paths must resolve."
        _r24_fail=1
      fi
    fi
    # l2_documents list
    if printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+l2_documents:[[:space:]]*\[\]'; then
      _in_l2_list24=0
    elif printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+l2_documents:[[:space:]]*$'; then
      _in_l2_list24=1
    elif printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+l2_documents:'; then
      _in_l2_list24=0
    elif [[ $_in_l2_list24 -eq 1 ]] && printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+-[[:space:]]+'; then
      _l2p24=$(printf '%s\n' "$_line24" | sed -E 's/^[[:space:]]+-[[:space:]]+(.*)/\1/')
      if [[ -n "$_l2p24" && ! -e "$_l2p24" ]]; then
        fail_rule "shipped_row_evidence_paths_exist" "$_status_path capability '$_current_key24' l2_documents entry '$_l2p24' not found on disk. Per ADR-0045 Gate Rule 24."
        _r24_fail=1
      fi
    elif [[ $_in_l2_list24 -eq 1 ]] && ! printf '%s\n' "$_line24" | grep -qE '^[[:space:]]+-'; then
      _in_l2_list24=0
    fi
  fi
done < "$_status_path"
if [[ $_r24_fail -eq 0 ]]; then pass_rule "shipped_row_evidence_paths_exist"; fi

# ---------------------------------------------------------------------------
# Rule 25 — peripheral_wave_qualifier
# ADR-0045: SPI Javadoc must not use "Primary sidecar impl:" or "Primary impl:"
# without a wave qualifier (W0-W4) in context. Active markdown docs must not use
# "Sidecar adapter —" without a wave qualifier or ADR reference. Closes PERIPHERAL-DRIFT.
# ---------------------------------------------------------------------------
_r25_fail=0
# 25a: SPI Java source in agent-runtime
while IFS= read -r _sf25; do
  [[ -z "$_sf25" ]] && continue
  if grep -q 'Primary sidecar impl:\|Primary impl:' "$_sf25" 2>/dev/null; then
    # For each matching line, check surrounding context for wave qualifier
    while IFS= read -r _hit25; do
      _ln25=$(printf '%s\n' "$_hit25" | grep -oE ':[0-9]+:' | tr -d ':' | head -1)
      _ctx25=$(sed -n "$((${_ln25:-0} > 2 ? ${_ln25} - 2 : 1)),$((${_ln25:-0} + 3))p" "$_sf25" 2>/dev/null | tr '\n' ' ')
      if ! printf '%s\n' "$_ctx25" | grep -qE '\bW[0-4]\b'; then
        fail_rule "peripheral_wave_qualifier" "$_sf25:$_ln25 contains 'Primary.*impl:' without wave qualifier (W0-W4) in context. Per ADR-0045 Gate Rule 25 future-wave impl claims must carry wave qualifiers."
        _r25_fail=1
      fi
    done < <(grep -nF 'Primary sidecar impl:' "$_sf25" 2>/dev/null; grep -nF 'Primary impl:' "$_sf25" 2>/dev/null)
  fi
done < <(find agent-runtime/src/main/java -name '*.java' ! -path './target/*' 2>/dev/null || true)
# 25b: active markdown docs
while IFS= read -r _af25; do
  [[ -z "$_af25" ]] && continue
  while IFS= read -r _mhit25; do
    _ln25m=$(printf '%s\n' "$_mhit25" | cut -d: -f1)
    _content25m=$(printf '%s\n' "$_mhit25" | cut -d: -f2-)
    if ! printf '%s\n' "$_content25m" | grep -qE '\bW[0-4]\b' && ! printf '%s\n' "$_content25m" | grep -q 'ADR-'; then
      fail_rule "peripheral_wave_qualifier" "$_af25:$_ln25m contains 'Sidecar adapter —' without wave qualifier or ADR reference. Per ADR-0045 Gate Rule 25."
      _r25_fail=1
    fi
  done < <(grep -nF 'Sidecar adapter —' "$_af25" 2>/dev/null || true)
done < <(find . -name '*.md' \
  ! -path './docs/archive/*' ! -path './docs/reviews/*' \
  ! -path './docs/adr/*' ! -path './docs/delivery/*' \
  ! -path './docs/v6-rationale/*' ! -path './docs/plans/*' \
  ! -path './third_party/*' ! -path './target/*' \
  ! -path './.git/*' \
  -type f 2>/dev/null | sort || true)
if [[ $_r25_fail -eq 0 ]]; then pass_rule "peripheral_wave_qualifier"; fi

# ---------------------------------------------------------------------------
# Rule 26 — release_note_shipped_surface_truth
# ADR-0046: docs/releases/*.md must not overclaim shipped surfaces.
#   26a — RunLifecycle name guard: line containing 'RunLifecycle' must be in a one-line
#         context window with a wave qualifier W1/W2/W3/W4, OR the same line must contain
#         one of: design-only|deferred|not shipped|remains design|materialised at W.
#   26b — RunContext method-list guard: line listing RunContext methods MUST NOT contain
#         posture() and method tokens must be subset of {runId,tenantId,checkpointer,suspendForChild}.
#   26c — OpenAPI snapshot attribution: ApiCompatibilityTest co-mentioned with
#         snapshot|OpenAPI.*spec|diverges fails (unless ArchUnit-only disclaimer present).
#   26d — AppPostureGate scope guard: 'AppPostureGate' on a line with 'HTTP Edge' fails;
#         'all runtime components.*posture.*constructor' fails.
# Closes GATE-SCOPE-GAP for release artifact class.
# ---------------------------------------------------------------------------
_r26_fail=0
if [[ -d docs/releases ]]; then
  while IFS= read -r _rf26; do
    [[ -z "$_rf26" ]] && continue
    # Pre-read file into an array of lines for context-window 26a.
    mapfile -t _rf26_lines < "$_rf26"
    _rf26_count=${#_rf26_lines[@]}
    for ((_i26=0; _i26 < _rf26_count; _i26++)); do
      _ln26="${_rf26_lines[$_i26]}"
      _lno26=$((_i26 + 1))
      # Narrative exemption: lines that explicitly describe Rule 26 itself are meta,
      # not shipped-surface claims. Skip them.
      if printf '%s' "$_ln26" | grep -qE 'Gate Rule 26|ADR-0046|release_note_shipped_surface_truth'; then
        continue
      fi
      # 26a: RunLifecycle name guard
      if printf '%s' "$_ln26" | grep -q 'RunLifecycle'; then
        _lo26=$((_i26 > 0 ? _i26 - 1 : 0))
        _hi26=$((_i26 + 1 < _rf26_count ? _i26 + 1 : _i26))
        _ctx26a=""
        for ((_j26=_lo26; _j26 <= _hi26; _j26++)); do
          _ctx26a="$_ctx26a ${_rf26_lines[$_j26]}"
        done
        _has_wave26a=0
        if printf '%s' "$_ctx26a" | grep -qE '(^|[^A-Za-z0-9])W[1-4]([^A-Za-z0-9]|$)'; then _has_wave26a=1; fi
        _has_marker26a=0
        if printf '%s' "$_ln26" | grep -qE 'design-only|deferred|not shipped|remains design|materialised at W|materialized at W'; then _has_marker26a=1; fi
        if [[ $_has_wave26a -eq 0 && $_has_marker26a -eq 0 ]]; then
          fail_rule "release_note_shipped_surface_truth" "$_rf26:$_lno26 (26a) contains 'RunLifecycle' without W1-W4 wave qualifier in context window or design-only/deferred/not shipped/remains design marker on the same line. Per ADR-0046."
          _r26_fail=1
        fi
      fi
      # 26b: RunContext method-list guard — only fires on methods-context lines
      # (table cell header, methods verb, or RunContext.method( syntax) and extracts
      # tokens only from the substring AFTER the first 'RunContext' occurrence.
      if printf '%s' "$_ln26" | grep -q 'RunContext'; then
        _is_methods_ctx26b=0
        if printf '%s' "$_ln26" | grep -qE '\|[[:space:]]*`?RunContext`?[[:space:]]*\|'; then _is_methods_ctx26b=1; fi
        if printf '%s' "$_ln26" | grep -qE 'RunContext[^.]{0,40}(exposes|interface|methods?|provides|carries|has)'; then _is_methods_ctx26b=1; fi
        if printf '%s' "$_ln26" | grep -qE 'RunContext\.[A-Za-z_]'; then _is_methods_ctx26b=1; fi
        if [[ $_is_methods_ctx26b -eq 1 ]]; then
          # Substring after first RunContext occurrence (POSIX awk).
          _after_rc26=$(printf '%s' "$_ln26" | awk '{ idx = index($0, "RunContext"); if (idx > 0) print substr($0, idx); }')
          if printf '%s' "$_after_rc26" | grep -qE '\bposture[[:space:]]*\('; then
            fail_rule "release_note_shipped_surface_truth" "$_rf26:$_lno26 (26b) contains 'RunContext' co-mentioned with 'posture()'. Per ADR-0046 RunContext has no posture(); canonical methods are runId/tenantId/checkpointer/suspendForChild."
            _r26_fail=1
          fi
          for _mt26 in $(printf '%s' "$_after_rc26" | grep -oE '\b[A-Za-z_][A-Za-z0-9_]*\(' | sed 's/($//'); do
            case "$_mt26" in
              [a-z]*)
                case "$_mt26" in
                  runId|tenantId|checkpointer|suspendForChild) : ;;
                  exposes|lists|returns|threads|carries|provides|sourced|interface|method|methods|requires|reads|writes|sees|gets|fails) : ;;
                  *)
                    fail_rule "release_note_shipped_surface_truth" "$_rf26:$_lno26 (26b) lists method '$_mt26()' alongside 'RunContext' in a methods-context. Per ADR-0046 canonical RunContext methods are {runId, tenantId, checkpointer, suspendForChild}; other tokens flag an invented method."
                    _r26_fail=1
                    ;;
                esac
                ;;
              *) : ;;
            esac
          done
        fi
      fi
      # 26c: OpenAPI snapshot test attribution
      if printf '%s' "$_ln26" | grep -q 'ApiCompatibilityTest' && \
         printf '%s' "$_ln26" | grep -qE 'snapshot|OpenAPI[[:space:]]*(snapshot|spec|v1)|diverges|live[[:space:]]*spec'; then
        if ! printf '%s' "$_ln26" | grep -qE 'ArchUnit[[:space:]]*-?[[:space:]]*only|not[[:space:]]+the[[:space:]]+OpenAPI|is[[:space:]]+not[[:space:]]+the[[:space:]]+OpenAPI'; then
          fail_rule "release_note_shipped_surface_truth" "$_rf26:$_lno26 (26c) attributes OpenAPI snapshot enforcement to ApiCompatibilityTest. Per ADR-0046 the snapshot diff lives in OpenApiContractIT (via OpenApiSnapshotComparator). ApiCompatibilityTest is ArchUnit-only."
          _r26_fail=1
        fi
      fi
      # 26d: AppPostureGate scope guard
      if printf '%s' "$_ln26" | grep -q 'AppPostureGate' && printf '%s' "$_ln26" | grep -qE 'HTTP[[:space:]]*Edge'; then
        fail_rule "release_note_shipped_surface_truth" "$_rf26:$_lno26 (26d) co-mentions 'AppPostureGate' with 'HTTP Edge'. Per ADR-0046 AppPostureGate lives in agent-runtime; it does not belong under HTTP Edge."
        _r26_fail=1
      fi
      if printf '%s' "$_ln26" | grep -qE 'all[[:space:]]+runtime[[:space:]]+components.*posture.*constructor|posture.*constructor.*all[[:space:]]+runtime[[:space:]]+components'; then
        fail_rule "release_note_shipped_surface_truth" "$_rf26:$_lno26 (26d) claims posture is a constructor argument for all runtime components. Per ADR-0046 only SyncOrchestrator, InMemoryRunRegistry, InMemoryCheckpointer call AppPostureGate; the claim is over-generalised."
        _r26_fail=1
      fi
    done
  done < <(find docs/releases -name '*.md' -type f 2>/dev/null | sort || true)
fi
if [[ $_r26_fail -eq 0 ]]; then pass_rule "release_note_shipped_surface_truth"; fi

# ---------------------------------------------------------------------------
# Rule 27 — active_entrypoint_baseline_truth
# ADR-0047: root README.md MUST contain the four architecture baseline counts
# currently asserted by docs/governance/architecture-status.yaml
# architecture_sync_gate.allowed_claim. Catches CANONICAL-DRIFT.
# ---------------------------------------------------------------------------
_r27_fail=0
if [[ -f docs/governance/architecture-status.yaml && -f README.md ]]; then
  # Extract the architecture_sync_gate.allowed_claim line (it is a single line in YAML).
  _claim27=$(awk '/^[[:space:]]+architecture_sync_gate:/{flag=1} flag && /allowed_claim:/{print; exit}' docs/governance/architecture-status.yaml)
  if [[ -z "$_claim27" ]]; then
    fail_rule "active_entrypoint_baseline_truth" "docs/governance/architecture-status.yaml missing architecture_sync_gate.allowed_claim line. Per ADR-0047 Gate Rule 27."
    _r27_fail=1
  else
    _readme27=$(cat README.md)
    _check_baseline27() {
      _label="$1"; _yaml_re="$2"; _readme_re="$3"
      _expected=$(printf '%s' "$_claim27" | grep -oE "$_yaml_re" | head -1 | grep -oE '^[0-9]+' | head -1)
      [[ -z "$_expected" ]] && return 0
      _readme_matches=$(printf '%s' "$_readme27" | grep -oE "$_readme_re")
      if [[ -z "$_readme_matches" ]]; then
        fail_rule "active_entrypoint_baseline_truth" "README.md missing baseline count for '$_label'. Per ADR-0047 Gate Rule 27 the README MUST contain '$_expected $_label' (current canonical baseline)."
        _r27_fail=1
        return 0
      fi
      while IFS= read -r _rm27; do
        _actual=$(printf '%s' "$_rm27" | grep -oE '^[0-9]+' | head -1)
        if [[ "$_actual" != "$_expected" ]]; then
          fail_rule "active_entrypoint_baseline_truth" "README.md asserts '$_actual $_label' but canonical baseline is '$_expected $_label'. Per ADR-0047 Gate Rule 27."
          _r27_fail=1
        fi
      done <<< "$_readme_matches"
    }
    _check_baseline27 '§4 constraints' '[0-9]+[[:space:]]+§4[[:space:]]+constraints' '[0-9]+[[:space:]]+§4[[:space:]]+constraints'
    _check_baseline27 'ADRs' '[0-9]+[[:space:]]+ADRs' '[0-9]+[[:space:]]+ADRs'
    _check_baseline27 'gate rules' '[0-9]+[[:space:]]+active[[:space:]]+gate[[:space:]]+rules' '[0-9]+[[:space:]]+(active[[:space:]]+)?gate[[:space:]]+rules'
    _check_baseline27 'self-tests' '[0-9]+[[:space:]]+gate[[:space:]]+self-tests' '[0-9]+[[:space:]]+(gate[[:space:]]+)?self-tests'
  fi
fi
if [[ $_r27_fail -eq 0 ]]; then pass_rule "active_entrypoint_baseline_truth"; fi

# ---------------------------------------------------------------------------
# Rule 28 — release_note_baseline_truth
# ADR-0049 (whitepaper-alignment remediation P0-1): every docs/releases/*.md
# baseline table MUST match the canonical architecture_sync_gate.allowed_claim
# counts, UNLESS the release note declares itself a historical artifact via
# the marker "Historical artifact frozen at SHA". Closes GATE-SCOPE-GAP for
# release-note baseline drift (Gate Rule 27 only covers README.md).
# ---------------------------------------------------------------------------
_r28_fail=0
if [[ -f docs/governance/architecture-status.yaml ]]; then
  _claim28=$(awk '/^[[:space:]]+architecture_sync_gate:/{flag=1} flag && /allowed_claim:/{print; exit}' docs/governance/architecture-status.yaml)
  if [[ -n "$_claim28" ]]; then
    while IFS= read -r _rf28; do
      [[ -z "$_rf28" ]] && continue
      if grep -qE 'Historical artifact frozen at SHA' "$_rf28"; then
        continue
      fi
      _rfcontent28=$(cat "$_rf28")
      _check_baseline28() {
        _label="$1"; _yaml_re="$2"; _rf_re="$3"
        _expected=$(printf '%s' "$_claim28" | grep -oE "$_yaml_re" | head -1 | grep -oE '^[0-9]+' | head -1)
        [[ -z "$_expected" ]] && return 0
        _rfmatches=$(printf '%s' "$_rfcontent28" | grep -oE "$_rf_re")
        if [[ -z "$_rfmatches" ]]; then
          fail_rule "release_note_baseline_truth" "$_rf28 missing baseline count for '$_label'. Per Gate Rule 28 active release notes must contain a table row matching '$_label | $_expected' or declare 'Historical artifact frozen at SHA <sha>'."
          _r28_fail=1
          return 0
        fi
        while IFS= read -r _rmline; do
          # Release notes use markdown-table format: '| <label> | <number> ... |'.
          # The number appears AFTER the label, so extract the trailing number.
          _actual=$(printf '%s' "$_rmline" | grep -oE '[0-9]+' | tail -1)
          if [[ "$_actual" != "$_expected" ]]; then
            fail_rule "release_note_baseline_truth" "$_rf28 asserts '$_actual' for '$_label' but canonical baseline is '$_expected $_label'. Per Gate Rule 28 active release notes must match the canonical baseline or declare 'Historical artifact frozen at SHA <sha>'."
            _r28_fail=1
          fi
        done <<< "$_rfmatches"
      }
      # Release-note table format: '| §4 constraints | 50 (#1–#50) |', etc.
      _check_baseline28 '§4 constraints' '[0-9]+[[:space:]]+§4[[:space:]]+constraints' '§4[[:space:]]+constraints[[:space:]]*\|[[:space:]]*[0-9]+'
      _check_baseline28 'ADRs' '[0-9]+[[:space:]]+ADRs' '(Active[[:space:]]+)?ADRs[[:space:]]*\|[[:space:]]*[0-9]+'
      _check_baseline28 'gate rules' '[0-9]+[[:space:]]+active[[:space:]]+gate[[:space:]]+rules' '(Active[[:space:]]+)?gate[[:space:]]+rules[[:space:]]*\|[[:space:]]*[0-9]+'
      _check_baseline28 'self-tests' '[0-9]+[[:space:]]+gate[[:space:]]+self-tests' '(Gate[[:space:]]+)?self-test[[:space:]]+cases[[:space:]]*\|[[:space:]]*[0-9]+'
    done < <(find docs/releases -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort || true)
  fi
fi
if [[ $_r28_fail -eq 0 ]]; then pass_rule "release_note_baseline_truth"; fi

# ---------------------------------------------------------------------------
# Rule 29 — whitepaper_alignment_matrix_present
# ADR-0049 + P2-1: docs/governance/whitepaper-alignment-matrix.md must exist
# and must contain rows for each of the 20 required whitepaper concepts.
# Closes the concept-traceability gap from the whitepaper-alignment review.
# ---------------------------------------------------------------------------
_r29_fail=0
_matrix29='docs/governance/whitepaper-alignment-matrix.md'
if [[ ! -f "$_matrix29" ]]; then
  fail_rule "whitepaper_alignment_matrix_present" "$_matrix29 missing. Per Gate Rule 29 / ADR-0049 the whitepaper alignment matrix must exist as concept-level traceability from whitepaper to active architecture."
  _r29_fail=1
else
  _required29=(
    'C/S separation'
    'Task Cursor'
    'Dynamic Hydration'
    'Sync State'
    'Sub-Stream'
    'Yield & Handoff'
    'Business ontology ownership'
    'S-side execution trajectory ownership'
    'Placeholder exemption'
    'Full Trace vs Node Snapshot'
    'Lazy mounting'
    'Skill Topology Scheduler'
    'C-side business degradation authority'
    'Session/context decoupling'
    'Workflow Intermediary'
    'Three-track bus'
    'Capability bidding'
    'Permission issuance'
    'Chronos Hydration'
    'Service Layer microservice commitment'
  )
  for _concept29 in "${_required29[@]}"; do
    if ! grep -qF "$_concept29" "$_matrix29"; then
      fail_rule "whitepaper_alignment_matrix_present" "$_matrix29 missing required concept row '$_concept29'. Per Gate Rule 29 all 20 named whitepaper concepts must appear in the alignment matrix."
      _r29_fail=1
    fi
  done
fi
if [[ $_r29_fail -eq 0 ]]; then pass_rule "whitepaper_alignment_matrix_present"; fi

# ---------------------------------------------------------------------------
# Rule 28a — tenant_column_present (Rule 28 sub-check, ADR-0059, enforcer E15)
# Every CREATE TABLE under any */src/main/resources/db/migration/*.sql that
# isn't a control/system table must declare a tenant_id column.
# Exemptions: health_check (singleton system row).
# ---------------------------------------------------------------------------
_r28a_fail=0
_python_bin=$(command -v python3 || command -v python || echo "")
while IFS= read -r _mig; do
  [[ -z "$_mig" ]] && continue
  if [[ -z "$_python_bin" ]]; then
    # No Python available — fall back to a crude shell heuristic: every
    # CREATE TABLE block must contain 'tenant_id' somewhere before its
    # terminating ';'. We use awk for the statement-level split.
    if awk '
      BEGIN { RS=";"; FS=""; IGNORECASE=1 }
      /CREATE[[:space:]]+TABLE/ {
        if ($0 ~ /health_check/) next
        if ($0 !~ /tenant_id/) { print "FAIL: " FILENAME; exit 1 }
      }
    ' "$_mig"; then :; else _r28a_fail=1; fi
    continue
  fi
  "$_python_bin" - "$_mig" <<'PY' || _r28a_fail=1
import re, sys
path = sys.argv[1]
text = open(path, encoding='utf-8').read()
# tokenize by semicolons; for each CREATE TABLE, inspect the body
for stmt in text.split(';'):
    m = re.search(r'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([a-zA-Z_][a-zA-Z0-9_]*)', stmt, re.IGNORECASE)
    if not m: continue
    name = m.group(1)
    if name in ('health_check',):
        continue
    if not re.search(r'\btenant_id\b', stmt, re.IGNORECASE):
        print(f"FAIL: {path}: table '{name}' lacks tenant_id column")
        sys.exit(1)
sys.exit(0)
PY
  if [[ $? -ne 0 ]]; then
    fail_rule "tenant_column_present" "$_mig declares a tenant-scoped table without a tenant_id column. Per Rule 28a / enforcer E15."
    _r28a_fail=1
  fi
done < <(find . -path '*/src/main/resources/db/migration/*.sql' -not -path './target/*' 2>/dev/null | sort || true)
if [[ $_r28a_fail -eq 0 ]]; then pass_rule "tenant_column_present"; fi

# ---------------------------------------------------------------------------
# Rule 28b — high_cardinality_tag_guard (enforcer E19)
# No source in agent-*/src/main/java registers Tag.of("run_id"|"idempotency_key"|
# "jwt_sub"|"body", ...) on a metric. The TenantTagMeterFilter scrubs these
# at runtime; the gate rejects them at commit time.
# ---------------------------------------------------------------------------
_r28b_fail=0
_forbidden_tag_pattern='Tag\.of\(\s*"(run_id|idempotency_key|jwt_sub|body)"'
_28b_hits=$(grep -rnE "$_forbidden_tag_pattern" \
  agent-platform/src/main/java agent-runtime/src/main/java 2>/dev/null || true)
if [[ -n "$_28b_hits" ]]; then
  fail_rule "high_cardinality_tag_guard" "Forbidden high-cardinality metric tag found:\n$_28b_hits\nPer Rule 28b / enforcer E19."
  _r28b_fail=1
fi
if [[ $_r28b_fail -eq 0 ]]; then pass_rule "high_cardinality_tag_guard"; fi

# ---------------------------------------------------------------------------
# Rule 28c — no_secret_patterns (enforcer E20)
# Crude regex sweep for common secret-leak shapes in tracked files.
# Excludes node_modules / target / .git / binary extensions. Files annotated
# with `secret-allowlist:` are exempt.
# Implemented as a single `git grep` for speed on Windows where per-file
# grep loops are pathologically slow.
# ---------------------------------------------------------------------------
_r28c_fail=0
# AWS access keys + private key blocks + GitHub PATs. The 'sk-' pattern was
# dropped — it false-matched documentation that names the regex shape itself.
_secret_patterns='AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|ghp_[A-Za-z0-9]{36}'
# docs/governance/enforcers.yaml is the index — it DOCUMENTS the patterns and
# is intentionally excluded; the index does not contain real secrets.
_28c_hits=$(git grep -lE "$_secret_patterns" -- ':!target/' ':!*.jar' ':!*.png' ':!*.jpg' ':!*.pdf' ':!docs/governance/enforcers.yaml' ':!gate/check_architecture_sync.sh' ':!gate/check_architecture_sync.ps1' 2>/dev/null || true)
if [[ -n "$_28c_hits" ]]; then
  while IFS= read -r _hit; do
    [[ -z "$_hit" ]] && continue
    if ! grep -q 'secret-allowlist:' "$_hit" 2>/dev/null; then
      fail_rule "no_secret_patterns" "$_hit appears to contain a secret pattern. Per Rule 28c / enforcer E20; add 'secret-allowlist: <reason>' inline if it is an intentional test fixture."
      _r28c_fail=1
    fi
  done <<< "$_28c_hits"
fi
if [[ $_r28c_fail -eq 0 ]]; then pass_rule "no_secret_patterns"; fi

# ---------------------------------------------------------------------------
# Rule 28d — out_of_scope_name_guard (enforcer E26)
# Names of W2+ deferred concepts (LLMGateway, PostgresCheckpointer,
# SkillRegistry, HookChain, SpawnEnvelope, LogicalCallHandle, ConnectionLease,
# AdmissionDecision, BackpressureSignal, ChronosHydration, SandboxExecutor)
# MUST NOT appear in agent-*/src/main/java. Test sources, ADRs, plans,
# release notes, and architecture-status.yaml are intentionally exempt.
# ---------------------------------------------------------------------------
_r28d_fail=0
_oos_names='LLMGateway|PostgresCheckpointer|SkillRegistry|HookChain|SpawnEnvelope|LogicalCallHandle|ConnectionLease|AdmissionDecision|BackpressureSignal|ChronosHydration|SandboxExecutor'
_28d_hits=$(grep -rnE "\\b($_oos_names)\\b" \
  agent-platform/src/main/java agent-runtime/src/main/java 2>/dev/null || true)
if [[ -n "$_28d_hits" ]]; then
  fail_rule "out_of_scope_name_guard" "W2+ out-of-scope name detected in main sources:\n$_28d_hits\nPer Rule 28d / enforcer E26 / plan §13."
  _r28d_fail=1
fi
if [[ $_r28d_fail -eq 0 ]]; then pass_rule "out_of_scope_name_guard"; fi

# ---------------------------------------------------------------------------
# Rule 28e — module_count_invariant (enforcer E27)
# Root pom.xml MUST declare exactly 4 <module> entries at L1 (spring-ai-ascend-
# dependencies, agent-platform, agent-runtime, spring-ai-ascend-graphmemory-
# starter). Any extra module is rejected; L1 plan decision D3.
# ---------------------------------------------------------------------------
_r28e_fail=0
_root_pom='pom.xml'
if [[ -f "$_root_pom" ]]; then
  _module_count=$(grep -c '<module>' "$_root_pom" 2>/dev/null || echo 0)
  if [[ "$_module_count" -ne 4 ]]; then
    fail_rule "module_count_invariant" "$_root_pom declares $_module_count <module> entries; L1 requires exactly 4. Per Rule 28e / enforcer E27 / plan decision D3."
    _r28e_fail=1
  fi
fi
if [[ $_r28e_fail -eq 0 ]]; then pass_rule "module_count_invariant"; fi

# ---------------------------------------------------------------------------
# Rule 28f — enforcers_yaml_wellformed (enforcer E29)
# docs/governance/enforcers.yaml MUST: exist, parse as YAML, contain a list
# where every row has all five fields (id, constraint_ref, kind, artifact,
# asserts) and kind is one of the five legal values.
# ---------------------------------------------------------------------------
_r28f_fail=0
_efile='docs/governance/enforcers.yaml'
if [[ ! -f "$_efile" ]]; then
  fail_rule "enforcers_yaml_wellformed" "$_efile missing. Per Rule 28f / enforcer E29 — Rule 28 cannot function without its index."
  _r28f_fail=1
elif [[ -z "$_python_bin" ]]; then
  # No Python — fall back to a coarse shell check: every '- id:' row must
  # be followed within 5 lines by 'constraint_ref:', 'kind:', 'artifact:',
  # 'asserts:'. Best-effort; the full schema validation requires Python.
  if ! grep -q '^- id:' "$_efile"; then
    fail_rule "enforcers_yaml_wellformed" "$_efile contains no '- id:' rows. Per Rule 28f / enforcer E29."
    _r28f_fail=1
  fi
else
  "$_python_bin" - "$_efile" <<'PY' || _r28f_fail=1
import sys, re
path = sys.argv[1]
with open(path, encoding='utf-8') as f:
    text = f.read()
# Required sub-fields under each '- id:' row (id is the boundary itself).
sub_required = ('constraint_ref', 'kind', 'artifact', 'asserts')
kinds = ('archunit', 'gate-script', 'integration', 'schema', 'compile-time')
# Split on the row boundary; drop the pre-list preamble (rows[0]).
rows = re.split(r'^- id:\s*', text, flags=re.MULTILINE)
errors = []
for raw in rows[1:]:
    block = raw  # first line is the ID, subsequent indented lines are the row
    first_line = block.splitlines()[0].strip()
    if not re.fullmatch(r'E\d+', first_line):
        errors.append(f"row id is not E<n>: '{first_line}'")
    for field in sub_required:
        if not re.search(rf'(^|\n)\s*{field}:', block):
            errors.append(f"row '{first_line}' missing field '{field}'")
    km = re.search(r'(^|\n)\s*kind:\s*([a-zA-Z\-]+)', block)
    if km and km.group(2) not in kinds:
        errors.append(f"row '{first_line}' has illegal kind '{km.group(2)}': expected one of {kinds}")
if errors:
    for e in errors:
        print(f"FAIL: {e}")
    sys.exit(1)
sys.exit(0)
PY
  if [[ $? -ne 0 ]]; then
    fail_rule "enforcers_yaml_wellformed" "$_efile rows are not well-formed. Per Rule 28f / enforcer E29."
    _r28f_fail=1
  fi
fi
if [[ $_r28f_fail -eq 0 ]]; then pass_rule "enforcers_yaml_wellformed"; fi

# ---------------------------------------------------------------------------
# Rule 28g — no_prose_only_constraint_marker (enforcer E30)
# Rule 28 forbids deferring an enforcer. Markers like "TODO: enforce",
# "FIXME: enforcer", "XXX: test", "deferred: gate" in CLAUDE.md /
# ARCHITECTURE.md / module ARCHITECTURE.md / docs/governance/*.yaml are bans.
# ---------------------------------------------------------------------------
_r28g_fail=0
_marker_pattern='(TODO|FIXME|XXX|deferred)[[:space:]]*:[[:space:]]*(enforce|enforcer|test|gate)\b'
# Canonical architecture-text files + every L1+ ADR (00[5-9]X glob). ADR-0059
# is exempt because it documents the marker patterns themselves; any future
# L1+ ADR that legitimately needs to document the markers must explicitly
# extend the _28g_exempt list (rather than silently drop out of scope).
# Phase K (audit fix F7): switched from a hardcoded list to a glob with an
# explicit exempt set so new ADRs are auto-covered.
_28g_files=(CLAUDE.md ARCHITECTURE.md)
while IFS= read -r _arch; do
  [[ -n "$_arch" ]] && _28g_files+=("$_arch")
done < <(ls agent-platform/ARCHITECTURE.md agent-runtime/ARCHITECTURE.md 2>/dev/null || true)
_28g_exempt=("docs/adr/0059-code-as-contract-architectural-enforcement.md")
while IFS= read -r _adr; do
  [[ -z "$_adr" ]] && continue
  _skip=0
  for _ex in "${_28g_exempt[@]}"; do
    [[ "$_adr" == "$_ex" ]] && _skip=1 && break
  done
  [[ $_skip -eq 0 ]] && _28g_files+=("$_adr")
done < <(ls docs/adr/00[5-9][0-9]-*.md 2>/dev/null | sort || true)
_28g_existing=()
for _f in "${_28g_files[@]}"; do
  [[ -f "$_f" ]] && _28g_existing+=("$_f")
done
_28g_hits=""
if (( ${#_28g_existing[@]} > 0 )); then
  _28g_hits=$(grep -nE "$_marker_pattern" "${_28g_existing[@]}" 2>/dev/null || true)
fi
if [[ -n "$_28g_hits" ]]; then
  fail_rule "no_prose_only_constraint_marker" "Rule-28-bypass marker found:\n$_28g_hits\nPer Rule 28g / enforcer E30."
  _r28g_fail=1
fi
if [[ $_r28g_fail -eq 0 ]]; then pass_rule "no_prose_only_constraint_marker"; fi

# ---------------------------------------------------------------------------
# Rule 28h — l1_review_checklist_present (enforcer E31)
# Every L1 ADR (0055–0059) MUST include the §16 review checklist subsection.
# ---------------------------------------------------------------------------
_r28h_fail=0
for _n in 0055 0056 0057 0058 0059 0060; do
  _adr=$(find docs/adr -maxdepth 1 -name "${_n}-*.md" 2>/dev/null | head -1)
  [[ -z "$_adr" ]] && continue
  if ! grep -qE '(§16 Review Checklist|L1 Review Checklist)' "$_adr" 2>/dev/null; then
    fail_rule "l1_review_checklist_present" "$_adr missing '§16 Review Checklist' subsection. Per Rule 28h / enforcer E31 / architect guidance §16."
    _r28h_fail=1
  fi
done
if [[ $_r28h_fail -eq 0 ]]; then pass_rule "l1_review_checklist_present"; fi

# ---------------------------------------------------------------------------
# Rule 28i — plan_enforcer_table_in_sync (enforcer E32)
# The L1 plan §11 table E<n> IDs MUST equal the set of `id:` fields in
# docs/governance/enforcers.yaml. The plan and the index are two views of the
# same truth.
# ---------------------------------------------------------------------------
_r28i_fail=0
_plan_file="$HOME/.claude/plans/l1-modular-russell.md"
# Fall back to alternative locations (Windows: /d/.claude/plans/...).
if [[ ! -f "$_plan_file" ]]; then
  _plan_file="/d/.claude/plans/l1-modular-russell.md"
fi
if [[ ! -f "$_plan_file" ]]; then
  # Plan lives outside the repo (user home). Skip with a NOTE.
  pass_rule "plan_enforcer_table_in_sync"
else
  _yaml_ids=$(grep -E '^- id: E[0-9]+' "$_efile" 2>/dev/null | sed -E 's/^- id:\s*//' | sort -u)
  _plan_ids=$(grep -oE '\| E[0-9]+ \|' "$_plan_file" 2>/dev/null | sed -E 's/\| (E[0-9]+) \|/\1/' | sort -u)
  if [[ -n "$_plan_ids" ]] && [[ "$_yaml_ids" != "$_plan_ids" ]]; then
    fail_rule "plan_enforcer_table_in_sync" "plan §11 enforcer IDs and enforcers.yaml IDs diverge. Per Rule 28i / enforcer E32."
    _r28i_fail=1
  fi
  if [[ $_r28i_fail -eq 0 ]]; then pass_rule "plan_enforcer_table_in_sync"; fi
fi

# ---------------------------------------------------------------------------
# Rule 28j — enforcer_artifact_paths_exist (Phase K F6 + Phase L P0-2, E33+E35)
# Every `artifact:` path in docs/governance/enforcers.yaml MUST resolve to a
# real file on disk. `#anchor` suffixes (e.g. `RunHttpContractIT.java#cancel...`
# or `check_architecture_sync.sh#rule_10`) MUST also resolve to a real method
# (.java/.sh) or heading (.md) inside that file. Phase L strengthens the
# file-only check (which let E5/E6/E24 ship with anchors pointing at methods
# that did not exist — closes reviewer finding P0-2).
# ---------------------------------------------------------------------------
_r28j_fail=0
if [[ -f "$_efile" ]]; then
  while IFS= read -r _aline; do
    [[ -z "$_aline" ]] && continue
    _aval=${_aline#*artifact:}
    _aval=${_aval#"${_aval%%[![:space:]]*}"}    # ltrim
    _aval=${_aval%"${_aval##*[![:space:]]}"}     # rtrim
    _apath=${_aval%%#*}                          # path side
    _aanchor=""
    case "$_aval" in
      *'#'*) _aanchor=${_aval#*#} ;;
    esac
    [[ -z "$_apath" ]] && continue
    if [[ ! -e "$_apath" ]]; then
      fail_rule "enforcer_artifact_paths_exist" "enforcers.yaml declares artifact path '$_apath' which does not exist on disk. Per Rule 28j / enforcer E33."
      _r28j_fail=1
      continue
    fi
    if [[ -n "$_aanchor" ]]; then
      _aok=1
      case "$_apath" in
        *.java)
          # Method declaration: `void <anchor>(`, `<modifiers> <anchor>(`
          if ! grep -qE "(void|\)|\>|\>[[:space:]])[[:space:]]+${_aanchor}[[:space:]]*\(" "$_apath" 2>/dev/null; then
            if ! grep -qE "^[[:space:]]*[a-zA-Z_<>][^()]*[[:space:]]${_aanchor}[[:space:]]*\(" "$_apath" 2>/dev/null; then
              _aok=0
            fi
          fi
          ;;
        *.sh|*.bash)
          # Bash function definition: `<anchor>()` or `function <anchor>` or comment `# Rule N — <anchor>`
          if ! grep -qE "(^|[[:space:]])${_aanchor}[[:space:]]*\(\)" "$_apath" 2>/dev/null; then
            if ! grep -qE "^[[:space:]]*function[[:space:]]+${_aanchor}\b" "$_apath" 2>/dev/null; then
              if ! grep -qE "^#[[:space:]]*Rule[[:space:]]+[0-9a-z]+[[:space:]]+(—|--)[[:space:]]+${_aanchor}\b" "$_apath" 2>/dev/null; then
                if ! grep -qE "\b(pass_rule|fail_rule)[[:space:]]+\"${_aanchor}\"" "$_apath" 2>/dev/null; then
                  _aok=0
                fi
              fi
            fi
          fi
          ;;
        *.md)
          # Markdown heading: `^#+ ... <anchor> ...` (loose match — anchor can be slug or phrase)
          if ! grep -qE "^#+[[:space:]].*${_aanchor}" "$_apath" 2>/dev/null; then
            _aok=0
          fi
          ;;
        *.yaml|*.yml)
          # YAML anchor: any line containing the anchor literal (loose check)
          if ! grep -q "${_aanchor}" "$_apath" 2>/dev/null; then
            _aok=0
          fi
          ;;
        *)
          # Other file types: just require literal presence
          if ! grep -q "${_aanchor}" "$_apath" 2>/dev/null; then
            _aok=0
          fi
          ;;
      esac
      if [[ $_aok -eq 0 ]]; then
        fail_rule "enforcer_artifact_paths_exist" "enforcers.yaml declares artifact anchor '$_apath#$_aanchor' but no method/heading/rule with that name exists in the target file. Per Rule 28j / enforcer E33 (anchor validation added in Phase L, enforcer E35)."
        _r28j_fail=1
      fi
    fi
  done < <(grep -E '^[[:space:]]*artifact:' "$_efile" 2>/dev/null || true)
fi
if [[ $_r28j_fail -eq 0 ]]; then pass_rule "enforcer_artifact_paths_exist"; fi

# ---------------------------------------------------------------------------
# Rule 28 — constraint_enforcer_coverage (meta-rule, enforcer E28)
#
# **L1 scope (Phase L truthful naming, per reviewer P2-1):** baseline presence
# check only. Verifies that `docs/governance/enforcers.yaml` references
# `CLAUDE.md` AND `ARCHITECTURE.md`. This is the smallest viable bootstrap
# meta-check — it does NOT parse every "must"/"forbidden"/"required" sentence
# in the corpus and cross-reference each one. Full natural-language parsing is
# deferred (no executable enforcer is feasible without committing to a brittle
# regex over evolving prose).
#
# Anchor-level truth is enforced by Rule 28j (`enforcer_artifact_paths_exist`,
# Phase L hardening), which validates that every `artifact: path#anchor`
# resolves to a real method (.java/.sh) or heading (.md) — closing reviewer
# finding P0-2.
# ---------------------------------------------------------------------------
_r28_fail=0
if [[ -f "$_efile" ]] && [[ -f 'CLAUDE.md' ]]; then
  if ! grep -q 'CLAUDE.md' "$_efile" 2>/dev/null; then
    fail_rule "constraint_enforcer_coverage" "enforcers.yaml does not reference CLAUDE.md at all; the meta-rule requires every active CLAUDE rule to map to an enforcer. Per Rule 28 / enforcer E28."
    _r28_fail=1
  fi
  if ! grep -q 'ARCHITECTURE.md' "$_efile" 2>/dev/null; then
    fail_rule "constraint_enforcer_coverage" "enforcers.yaml does not reference ARCHITECTURE.md; §4 constraints must map to enforcers. Per Rule 28 / enforcer E28."
    _r28_fail=1
  fi
fi
if [[ $_r28_fail -eq 0 ]]; then pass_rule "constraint_enforcer_coverage"; fi

# ---------------------------------------------------------------------------
# Rule 30 — telemetry_vertical_constraint_coverage (enforcer E47)
#
# Telemetry Vertical L1.x (ADR-0061 / §4 #53–#59): every Telemetry-Vertical
# constraint number in ARCHITECTURE.md §4 MUST resolve to at least one
# enforcer row in docs/governance/enforcers.yaml. Stricter than the existing
# meta-rule 28 (presence check only) — Rule 30 validates each §4 #N reference
# individually for N in {53..59}.
# ---------------------------------------------------------------------------
_r30_fail=0
_efile='docs/governance/enforcers.yaml'
_archfile='ARCHITECTURE.md'
if [[ -f "$_archfile" && -f "$_efile" ]]; then
  for _n in 53 54 55 56 57 58 59; do
    # Constraint number must exist in ARCHITECTURE.md §4 as a top-level numbered item.
    if ! grep -qE "^${_n}\. \*\*" "$_archfile"; then
      fail_rule "telemetry_vertical_constraint_coverage" "ARCHITECTURE.md §4 #${_n} (Telemetry Vertical) is missing — expected '${_n}. **' at line start. Per ADR-0061 §8."
      _r30_fail=1
      continue
    fi
    # And the constraint number must be cited in at least one enforcer row.
    if ! grep -qE "§4 #${_n}" "$_efile"; then
      fail_rule "telemetry_vertical_constraint_coverage" "enforcers.yaml has no row citing '§4 #${_n}' (Telemetry Vertical). Add an E-row per ADR-0061 §8 + Rule 28."
      _r30_fail=1
    fi
  done
fi
if [[ $_r30_fail -eq 0 ]]; then pass_rule "telemetry_vertical_constraint_coverage"; fi

# ---------------------------------------------------------------------------
# Rule 31 — quickstart_present (enforcer E49, CLAUDE.md Rule 29 / ADR-0064)
#
# docs/quickstart.md MUST exist and MUST be referenced from README.md so a
# developer can reach first-agent execution without platform-team intervention.
# ---------------------------------------------------------------------------
_r31_fail=0
if [[ ! -f "docs/quickstart.md" ]]; then
  fail_rule "quickstart_present" "docs/quickstart.md is missing (CLAUDE.md Rule 29 / ADR-0064)"
  _r31_fail=1
fi
if [[ -f "README.md" ]] && ! grep -q "docs/quickstart.md" "README.md" 2>/dev/null; then
  fail_rule "quickstart_present" "README.md does not reference docs/quickstart.md (CLAUDE.md Rule 29)"
  _r31_fail=1
fi
if [[ $_r31_fail -eq 0 ]]; then pass_rule "quickstart_present"; fi

# ---------------------------------------------------------------------------
# Rule 32 — competitive_baselines_present_and_wellformed (enforcer E50, ADR-0065)
#
# docs/governance/competitive-baselines.yaml MUST exist and MUST declare four
# dimensions: performance, cost, developer_onboarding, governance.
# ---------------------------------------------------------------------------
_r32_fail=0
_baseline_file="docs/governance/competitive-baselines.yaml"
if [[ ! -f "$_baseline_file" ]]; then
  fail_rule "competitive_baselines_present_and_wellformed" "$_baseline_file is missing (CLAUDE.md Rule 30 / ADR-0065)"
  _r32_fail=1
else
  for _dim in performance cost developer_onboarding governance; do
    if ! grep -qE "^[[:space:]]*${_dim}:" "$_baseline_file" 2>/dev/null; then
      fail_rule "competitive_baselines_present_and_wellformed" "$_baseline_file missing required dimension '${_dim}'"
      _r32_fail=1
    fi
  done
fi
if [[ $_r32_fail -eq 0 ]]; then pass_rule "competitive_baselines_present_and_wellformed"; fi

# ---------------------------------------------------------------------------
# Rule 33 — release_note_references_four_pillars (enforcer E51, ADR-0065)
#
# The most recent release note under docs/releases/ MUST mention all four
# pillar names by name so reviewers see the dimensions tracked per release.
# ---------------------------------------------------------------------------
_r33_fail=0
_latest_release="$(find docs/releases -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort | tail -1 || true)"
if [[ -z "$_latest_release" ]]; then
  pass_rule "release_note_references_four_pillars"   # no release notes yet — vacuous pass
else
  _missing_pillars=""
  for _p in performance cost developer_onboarding governance; do
    if ! grep -qiE "\b${_p}\b" "$_latest_release" 2>/dev/null; then
      _missing_pillars="${_missing_pillars} ${_p}"
    fi
  done
  if [[ -n "$_missing_pillars" ]]; then
    fail_rule "release_note_references_four_pillars" "$(basename "$_latest_release") does not mention pillar(s):${_missing_pillars} (CLAUDE.md Rule 30 / ADR-0065)"
    _r33_fail=1
  fi
fi
if [[ $_r33_fail -eq 0 ]] && [[ -n "$_latest_release" ]]; then pass_rule "release_note_references_four_pillars"; fi

# ---------------------------------------------------------------------------
# Rule 34 — module_metadata_present_and_complete (enforcer E52, ADR-0066)
#
# Every reactor module (every <module>/pom.xml) MUST have a sibling
# module-metadata.yaml declaring module, kind, version, semver_compatibility.
# Required by CLAUDE.md Rule 31.
# ---------------------------------------------------------------------------
_r34_fail=0
_required_keys=(module kind version semver_compatibility)
while IFS= read -r _pom; do
  [[ -z "$_pom" ]] && continue
  # Skip the root reactor pom — it's the reactor declaration, not a module
  if [[ "$_pom" == "./pom.xml" || "$_pom" == "pom.xml" ]]; then continue; fi
  _mod_dir="$(dirname "$_pom")"
  _meta="${_mod_dir}/module-metadata.yaml"
  if [[ ! -f "$_meta" ]]; then
    fail_rule "module_metadata_present_and_complete" "$_meta missing — required for ${_mod_dir} (CLAUDE.md Rule 31 / ADR-0066)"
    _r34_fail=1
    continue
  fi
  for _k in "${_required_keys[@]}"; do
    if ! grep -qE "^[[:space:]]*${_k}:" "$_meta" 2>/dev/null; then
      fail_rule "module_metadata_present_and_complete" "$_meta missing required key '${_k}'"
      _r34_fail=1
    fi
  done
done < <(find . -mindepth 2 -maxdepth 2 -name 'pom.xml' -type f 2>/dev/null | sort || true)
if [[ $_r34_fail -eq 0 ]]; then pass_rule "module_metadata_present_and_complete"; fi

# ---------------------------------------------------------------------------
# Rule 35 — dfx_yaml_present_and_wellformed (enforcer E53, ADR-0067)
#
# Every module with kind ∈ {platform, domain} in its module-metadata.yaml
# MUST have a docs/dfx/<module>.yaml covering five DFX dimensions:
# releasability, resilience, availability, vulnerability, observability.
# DFX is OPTIONAL for kind ∈ {bom, starter, sample}.
# Required by CLAUDE.md Rule 32.
# ---------------------------------------------------------------------------
_r35_fail=0
_dfx_required_kinds_re='^(platform|domain)$'
while IFS= read -r _meta; do
  [[ -z "$_meta" ]] && continue
  _kind="$(grep -E '^[[:space:]]*kind:' "$_meta" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*kind:[[:space:]]*([A-Za-z_]+).*/\1/')"
  [[ ! "$_kind" =~ $_dfx_required_kinds_re ]] && continue
  _mod_name="$(grep -E '^[[:space:]]*module:' "$_meta" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*module:[[:space:]]*([A-Za-z0-9_-]+).*/\1/')"
  _dfx="docs/dfx/${_mod_name}.yaml"
  if [[ ! -f "$_dfx" ]]; then
    fail_rule "dfx_yaml_present_and_wellformed" "$_dfx missing — required for kind=${_kind} module '${_mod_name}' (CLAUDE.md Rule 32 / ADR-0067)"
    _r35_fail=1
    continue
  fi
  for _d in releasability resilience availability vulnerability observability; do
    if ! grep -qE "^[[:space:]]*${_d}:" "$_dfx" 2>/dev/null; then
      fail_rule "dfx_yaml_present_and_wellformed" "$_dfx missing required DFX dimension '${_d}'"
      _r35_fail=1
    fi
  done
done < <(find . -mindepth 2 -maxdepth 2 -name 'module-metadata.yaml' -type f 2>/dev/null | sort || true)
if [[ $_r35_fail -eq 0 ]]; then pass_rule "dfx_yaml_present_and_wellformed"; fi

# ---------------------------------------------------------------------------
# Rule 36 — domain_module_has_spi_package (enforcer E54, ADR-0067)
#
# Every module with kind=domain in its module-metadata.yaml MUST declare at
# least one entry under `spi_packages:` AND each declared package MUST exist
# as a directory under <module>/src/main/java/. Required by CLAUDE.md Rule 32.
# ---------------------------------------------------------------------------
_r36_fail=0
while IFS= read -r _meta; do
  [[ -z "$_meta" ]] && continue
  _kind="$(grep -E '^[[:space:]]*kind:' "$_meta" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*kind:[[:space:]]*([A-Za-z_]+).*/\1/')"
  [[ "$_kind" != "domain" ]] && continue
  _mod_dir="$(dirname "$_meta")"
  # Extract spi_packages list entries (lines under spi_packages: that look like "  - <pkg>")
  _has_entry=0
  _pkg_lines="$(awk '/^[[:space:]]*spi_packages:/{flag=1; next} /^[A-Za-z_]/{flag=0} flag && /^[[:space:]]*-[[:space:]]*[A-Za-z0-9._-]+/{print}' "$_meta" 2>/dev/null || true)"
  if [[ -z "$_pkg_lines" ]]; then
    fail_rule "domain_module_has_spi_package" "$_meta declares kind=domain but has no spi_packages entries (CLAUDE.md Rule 32 / ADR-0067)"
    _r36_fail=1
    continue
  fi
  while IFS= read -r _ln; do
    _pkg="$(printf '%s\n' "$_ln" | sed -E 's/^[[:space:]]*-[[:space:]]*([A-Za-z0-9._-]+).*/\1/')"
    [[ -z "$_pkg" ]] && continue
    _has_entry=1
    _pkg_path="$(printf '%s\n' "$_pkg" | tr '.' '/')"
    _dir="${_mod_dir}/src/main/java/${_pkg_path}"
    if [[ ! -d "$_dir" ]]; then
      fail_rule "domain_module_has_spi_package" "$_meta declares spi_package '${_pkg}' but directory ${_dir} does not exist"
      _r36_fail=1
    fi
  done <<< "$_pkg_lines"
  if [[ $_has_entry -eq 0 ]]; then
    fail_rule "domain_module_has_spi_package" "$_meta declares kind=domain but spi_packages list is empty"
    _r36_fail=1
  fi
done < <(find . -mindepth 2 -maxdepth 2 -name 'module-metadata.yaml' -type f 2>/dev/null | sort || true)
if [[ $_r36_fail -eq 0 ]]; then pass_rule "domain_module_has_spi_package"; fi

# ===========================================================================
# W1 Layered-4+1 + Architecture-Graph wave (CLAUDE.md Rules 33-34, ADR-0068)
# Gate Rules 37-40 enforce the front-matter discipline and the machine-readable
# graph index. See enforcers.yaml rows E55-E59.
# ===========================================================================

# ---------------------------------------------------------------------------
# Rule 37 — architecture_artefact_front_matter (enforcer E55, ADR-0068)
#
# Every L0/L1/L2 architecture artefact MUST declare a level: + view:
# front-matter (YAML at top of file for .md; top-level key for .yaml).
# Targets: ARCHITECTURE.md, agent-*/ARCHITECTURE.md, docs/L2/**/*.md (excluding
# README.md while empty), docs/adr/*.yaml.
# ---------------------------------------------------------------------------
_r37_fail=0
_valid_levels='^(L0|L1|L2)$'
_valid_views='^(logical|development|process|physical|scenarios)$'

_check_front_matter_md() {
  local _f="$1"
  local _level _view
  _level="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^level:[[:space:]]/{sub(/^level:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$_f" 2>/dev/null)"
  _view="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^view:[[:space:]]/{sub(/^view:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$_f" 2>/dev/null)"
  if [[ -z "$_level" ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f missing 'level:' YAML front-matter (CLAUDE.md Rule 33 / ADR-0068)"; _r37_fail=1; return
  fi
  if [[ ! "$_level" =~ $_valid_levels ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f level: '$_level' is not one of L0|L1|L2"; _r37_fail=1
  fi
  if [[ -z "$_view" ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f missing 'view:' YAML front-matter (CLAUDE.md Rule 33 / ADR-0068)"; _r37_fail=1; return
  fi
  if [[ ! "$_view" =~ $_valid_views ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f view: '$_view' is not one of logical|development|process|physical|scenarios"; _r37_fail=1
  fi
}

_check_front_matter_yaml() {
  local _f="$1"
  local _level _view
  _level="$(grep -E '^level:[[:space:]]' "$_f" 2>/dev/null | head -1 | sed -E 's/^level:[[:space:]]*([A-Za-z0-9_]+).*/\1/')"
  _view="$(grep -E '^view:[[:space:]]' "$_f" 2>/dev/null | head -1 | sed -E 's/^view:[[:space:]]*([A-Za-z0-9_]+).*/\1/')"
  if [[ -z "$_level" ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f missing top-level 'level:' (CLAUDE.md Rule 33 / ADR-0068)"; _r37_fail=1; return
  fi
  if [[ ! "$_level" =~ $_valid_levels ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f level: '$_level' is not one of L0|L1|L2"; _r37_fail=1
  fi
  if [[ -z "$_view" ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f missing top-level 'view:' (CLAUDE.md Rule 33 / ADR-0068)"; _r37_fail=1; return
  fi
  if [[ ! "$_view" =~ $_valid_views ]]; then
    fail_rule "architecture_artefact_front_matter" "$_f view: '$_view' is not one of logical|development|process|physical|scenarios"; _r37_fail=1
  fi
}

[[ -f ARCHITECTURE.md ]] && _check_front_matter_md ARCHITECTURE.md
while IFS= read -r _f37; do
  [[ -z "$_f37" ]] && continue
  _check_front_matter_md "$_f37"
done < <(find . -maxdepth 2 -type f -name 'ARCHITECTURE.md' ! -path './ARCHITECTURE.md' 2>/dev/null | sort || true)
while IFS= read -r _f37; do
  [[ -z "$_f37" ]] && continue
  _check_front_matter_md "$_f37"
done < <(find docs/L2 -type f -name '*.md' 2>/dev/null | sort || true)
while IFS= read -r _f37; do
  [[ -z "$_f37" ]] && continue
  _check_front_matter_yaml "$_f37"
done < <(find docs/adr -maxdepth 1 -type f -name '*.yaml' 2>/dev/null | sort || true)
if [[ $_r37_fail -eq 0 ]]; then pass_rule "architecture_artefact_front_matter"; fi

# ---------------------------------------------------------------------------
# Rule 38 — architecture_graph_well_formed (enforcer E56, ADR-0068)
#
# docs/governance/architecture-graph.yaml MUST regenerate idempotently from
# authoritative inputs. The build script runs --check and exits non-zero on
# any validation error (missing endpoint, missing file, cycle in
# supersedes/extends, anchor not resolvable).
# ---------------------------------------------------------------------------
_r38_fail=0
if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  fail_rule "architecture_graph_well_formed" "neither python3 nor python on PATH — required for gate/build_architecture_graph.py (CLAUDE.md Rule 34)"; _r38_fail=1
else
  _r38_tmp1="$(mktemp 2>/dev/null || echo /tmp/r38_a.yaml)"
  _r38_tmp2="$(mktemp 2>/dev/null || echo /tmp/r38_b.yaml)"
  # Build twice, diff outputs (idempotency).
  if ! bash gate/build_architecture_graph.sh > /dev/null 2> "$_r38_tmp1"; then
    fail_rule "architecture_graph_well_formed" "gate/build_architecture_graph.sh failed: $(cat "$_r38_tmp1")"; _r38_fail=1
  else
    cp docs/governance/architecture-graph.yaml "$_r38_tmp1" 2>/dev/null || true
    if ! bash gate/build_architecture_graph.sh --no-write --check > /dev/null 2> "$_r38_tmp2"; then
      fail_rule "architecture_graph_well_formed" "graph validation failed: $(cat "$_r38_tmp2")"; _r38_fail=1
    fi
  fi
  rm -f "$_r38_tmp1" "$_r38_tmp2" 2>/dev/null || true
fi
if [[ $_r38_fail -eq 0 ]]; then pass_rule "architecture_graph_well_formed"; fi

# ---------------------------------------------------------------------------
# Rule 39 — review_proposal_front_matter (enforcer E57, ADR-0068)
#
# Every NEW (post-W1) proposal under docs/reviews/ MUST declare
# affects_level: + affects_view: front-matter. Pre-W1 historical review
# files are explicitly listed in the allow-list below and exempted.
# ---------------------------------------------------------------------------
_r39_fail=0
# Allow-list of pre-W1 historical files (relative to docs/reviews/).
_r39_allow_re='^(2026-05-1[23]-|2026-05-14-(architecture-governance-in-vibe-coding-era|L0Architecture-LucioIT-wave-1-request|l1-architecture-expert-review)|spring-ai-ascend-implementation-guidelines|Architectural Perspective Review)'
while IFS= read -r _f39; do
  [[ -z "$_f39" ]] && continue
  _base="$(basename "$_f39")"
  [[ "$_base" == "_TEMPLATE.md" ]] && continue
  if [[ "$_base" =~ $_r39_allow_re ]]; then continue; fi
  if ! grep -qE '^affects_level:[[:space:]]+(L0|L1|L2)' "$_f39" 2>/dev/null; then
    fail_rule "review_proposal_front_matter" "$_f39 missing 'affects_level:' front-matter (CLAUDE.md Rule 33 / ADR-0068)"; _r39_fail=1
  fi
  if ! grep -qE '^affects_view:[[:space:]]+(logical|development|process|physical|scenarios)' "$_f39" 2>/dev/null; then
    fail_rule "review_proposal_front_matter" "$_f39 missing 'affects_view:' front-matter (CLAUDE.md Rule 33 / ADR-0068)"; _r39_fail=1
  fi
done < <(find docs/reviews -maxdepth 1 -type f -name '*.md' 2>/dev/null | sort || true)
if [[ $_r39_fail -eq 0 ]]; then pass_rule "review_proposal_front_matter"; fi

# ---------------------------------------------------------------------------
# Rule 40 — enforcer_reachable_from_principle (enforcer E58, ADR-0068)
#
# Every shipped enforcer row in docs/governance/enforcers.yaml MUST be
# reachable from at least one Layer-0 principle (P-A..P-D or legacy
# P1..P3/E1) through the edge chain in architecture-graph.yaml:
#   principle --operationalised_by--> Rule-N --enforced_by--> E<n>
# The Python graph builder owns the traversal; this rule delegates to it.
# ---------------------------------------------------------------------------
_r40_fail=0
if [[ ! -f docs/governance/architecture-graph.yaml ]]; then
  fail_rule "enforcer_reachable_from_principle" "docs/governance/architecture-graph.yaml not present — run gate/build_architecture_graph.sh first"; _r40_fail=1
else
  # Embedded traversal check (avoids second Python invocation). For every
  # enforcer node E<n>, confirm there exists at least one Rule-N node feeding
  # it and that Rule-N is operationalised by at least one principle.
  _r40_orphans="$(awk '
    /^- id: / {
      if (cur != "" && type == "enforcer") enforcers[cur] = 1
      cur = $3
      type = ""
    }
    /^  type: enforcer/ { type = "enforcer" }
    /^  type: rule/    { rules_seen[cur] = 1 }
    /^  type: principle/ { principles_seen[cur] = 1 }
    /^- src: / { src = $3 }
    /^  dst: / { dst = $3 }
    /^  type: enforced_by/ { rule_to_enf[src] = rule_to_enf[src] " " dst; enf_has_rule[dst] = 1 }
    /^  type: operationalised_by/ { prin_to_rule[src] = prin_to_rule[src] " " dst; rule_has_prin[dst] = 1 }
    END {
      for (e in enforcers) {
        if (!(e in enf_has_rule)) {
          print "  - " e " (no rule -> enforcer edge)"
          orphan++
        }
      }
      if (orphan > 0) exit 1
    }
  ' docs/governance/architecture-graph.yaml 2>/dev/null || true)"
  if [[ -n "$_r40_orphans" ]]; then
    fail_rule "enforcer_reachable_from_principle" "orphaned enforcer(s): no rule path back to a principle:"
    echo "$_r40_orphans" >&2
    _r40_fail=1
  fi
fi
if [[ $_r40_fail -eq 0 ]]; then pass_rule "enforcer_reachable_from_principle"; fi

# ===========================================================================
# Phase M remediation (CLAUDE.md Rules 33-34, ADR-0068)
# Rules 41-44 close the self-violations the W1 wave inherited from Rule 28:
# anchor validation, idempotency, ADR-shape, frozen-doc edit path.
# Enforcer rows E60-E63 in docs/governance/enforcers.yaml.
# ===========================================================================

# ---------------------------------------------------------------------------
# Rule 41 — enforcer_anchor_resolves (enforcer E60, Phase M B2)
#
# Every artefact node in architecture-graph.yaml that carries an `anchor:`
# MUST also carry `anchor_resolves: true`. Closes the L1-expert P0-2 / P2-1
# gap: previously an enforcer row could point at a non-existent test method
# and pass Rule 28j (file-path existence). The graph builder now resolves
# anchors per file type (.java method declaration, .md heading, .sh function,
# .yaml top-level key) and this gate fails on any false.
# ---------------------------------------------------------------------------
_r41_fail=0
if [[ ! -f docs/governance/architecture-graph.yaml ]]; then
  fail_rule "enforcer_anchor_resolves" "docs/governance/architecture-graph.yaml not present — run bash gate/build_architecture_graph.sh first"
  _r41_fail=1
else
  # Scan the graph for any artefact node with anchor: <non-null> and anchor_resolves: false.
  _r41_offenders="$(awk '
    /^- id:/      { cur=$3; type=""; anchor=""; resolves="" }
    /^  type:/    { type=$2 }
    /^  path:/    { path=substr($0, index($0, ":")+2) }
    /^  anchor:/  {
      val = substr($0, index($0, ":")+2)
      gsub(/[[:space:]]+$/, "", val)
      anchor = val
    }
    /^  anchor_resolves:/ {
      val = substr($0, index($0, ":")+2)
      gsub(/[[:space:]]+$/, "", val)
      resolves = val
      if (type == "artefact" && anchor != "" && anchor != "null" && resolves == "false") {
        print "  - " cur " (path " path ", anchor " anchor ")"
      }
    }
  ' docs/governance/architecture-graph.yaml 2>/dev/null || true)"
  if [[ -n "$_r41_offenders" ]]; then
    fail_rule "enforcer_anchor_resolves" "unresolved anchor(s) — fix enforcer row or rename target method/heading:"
    echo "$_r41_offenders" >&2
    _r41_fail=1
  fi
fi
if [[ $_r41_fail -eq 0 ]]; then pass_rule "enforcer_anchor_resolves"; fi

# ---------------------------------------------------------------------------
# Rule 42 — architecture_graph_idempotent (enforcer E61, Phase M B3)
#
# Building the architecture graph twice on unchanged inputs MUST produce a
# byte-identical output. Closes the Rule 34 normative phrase "build script
# MUST be idempotent" which previously had no enforcer.
# ---------------------------------------------------------------------------
_r42_fail=0
if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  fail_rule "architecture_graph_idempotent" "neither python3 nor python on PATH — required for gate/build_architecture_graph.py"
  _r42_fail=1
elif [[ ! -f docs/governance/architecture-graph.yaml ]]; then
  fail_rule "architecture_graph_idempotent" "docs/governance/architecture-graph.yaml not present — run bash gate/build_architecture_graph.sh first"
  _r42_fail=1
else
  _r42_a="$(mktemp 2>/dev/null || echo /tmp/r42_a.yaml)"
  _r42_b="$(mktemp 2>/dev/null || echo /tmp/r42_b.yaml)"
  cp docs/governance/architecture-graph.yaml "$_r42_a" 2>/dev/null || true
  if ! bash gate/build_architecture_graph.sh > /dev/null 2>&1; then
    fail_rule "architecture_graph_idempotent" "graph build failed during idempotency probe"
    _r42_fail=1
  else
    cp docs/governance/architecture-graph.yaml "$_r42_b" 2>/dev/null || true
    if ! diff -q "$_r42_a" "$_r42_b" >/dev/null 2>&1; then
      fail_rule "architecture_graph_idempotent" "re-running gate/build_architecture_graph.sh produced a DIFFERENT graph — the build is non-deterministic"
      _r42_fail=1
    fi
  fi
  rm -f "$_r42_a" "$_r42_b" 2>/dev/null || true
fi
if [[ $_r42_fail -eq 0 ]]; then pass_rule "architecture_graph_idempotent"; fi

# ---------------------------------------------------------------------------
# Rule 43 — new_adr_must_be_yaml (enforcer E62, Phase M D2)
#
# The highest-numbered ADR file under docs/adr/NNNN-*.{md,yaml} MUST have the
# .yaml extension. This prevents future ADRs from regressing to the legacy
# .md shape after ADR-0068 mandated YAML.
# ---------------------------------------------------------------------------
_r43_fail=0
_r43_top_md="$(find docs/adr -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.md' 2>/dev/null | sort -r | head -1 || true)"
_r43_top_yaml="$(find docs/adr -maxdepth 1 -type f -name '[0-9][0-9][0-9][0-9]-*.yaml' 2>/dev/null | sort -r | head -1 || true)"
_r43_top_md_n="$(basename "${_r43_top_md:-0000-x.md}" 2>/dev/null | cut -c1-4)"
_r43_top_yaml_n="$(basename "${_r43_top_yaml:-0000-x.yaml}" 2>/dev/null | cut -c1-4)"
# Force base-10 (4-digit ADR ids can have leading zeros which bash otherwise reads as octal,
# making "0068" / "0099" invalid in arithmetic comparisons).
if (( 10#${_r43_top_md_n:-0} > 10#${_r43_top_yaml_n:-0} )); then
  fail_rule "new_adr_must_be_yaml" "highest-numbered ADR is $_r43_top_md (.md) — ADR-0068 / Rule 33 mandates all new ADRs be .yaml; rename or migrate"
  _r43_fail=1
fi
if [[ $_r43_fail -eq 0 ]]; then pass_rule "new_adr_must_be_yaml"; fi

# ---------------------------------------------------------------------------
# Rule 44 — frozen_doc_edit_path_compliance (enforcer E63, Phase M D4)
#
# For every architecture artefact declaring `freeze_id: <non-null>` in its
# front-matter, any modification to that file in the working tree (vs the
# merge base) MUST be accompanied by a NEW docs/reviews/*.md proposal in the
# same commit naming the file under `affects_artefact:`. No-op today (all
# freeze_id values are null); arms automatically when a doc is phase-released.
# ---------------------------------------------------------------------------
_r44_fail=0
_r44_base="${BASE_REF:-origin/main}"
# Collect frozen-doc paths.
_r44_frozen=""
for _f44 in ARCHITECTURE.md $(find . -maxdepth 2 -type f -name 'ARCHITECTURE.md' ! -path './ARCHITECTURE.md' 2>/dev/null || true) \
            $(find docs/L2 -type f -name '*.md' 2>/dev/null || true) \
            $(find docs/adr -maxdepth 1 -type f -name '*.yaml' 2>/dev/null || true); do
  [[ -z "$_f44" || ! -f "$_f44" ]] && continue
  _fid="$(awk 'BEGIN{in_fm=0; n=0} /^---[[:space:]]*$/{n++; if(n==1){in_fm=1; next} if(n==2){exit}} in_fm && /^freeze_id:[[:space:]]/{sub(/^freeze_id:[[:space:]]*/,""); sub(/[[:space:]]*$/,""); print; exit}' "$_f44" 2>/dev/null)"
  # YAML ADR (top-level key, no front-matter delimiters)
  if [[ -z "$_fid" ]]; then
    _fid="$(grep -E '^freeze_id:[[:space:]]' "$_f44" 2>/dev/null | head -1 | sed -E 's/^freeze_id:[[:space:]]*([A-Za-z0-9._-]+).*/\1/')"
  fi
  if [[ -n "$_fid" && "$_fid" != "null" ]]; then
    _r44_frozen="${_r44_frozen}${_f44}\n"
  fi
done
# If git is available and a base ref is reachable, check each frozen doc for
# modifications without an accompanying review proposal.
if [[ -n "$_r44_frozen" ]] && command -v git >/dev/null 2>&1 && git rev-parse --verify "$_r44_base" >/dev/null 2>&1; then
  _r44_changed_reviews="$(git diff --name-only --diff-filter=A "$_r44_base" -- 'docs/reviews/*.md' 2>/dev/null || true)"
  while IFS= read -r _f44; do
    [[ -z "$_f44" ]] && continue
    if git diff --name-only "$_r44_base" -- "$_f44" 2>/dev/null | grep -q .; then
      # Frozen doc was modified; require a review proposal naming it in affects_artefact:.
      _accompanied=0
      while IFS= read -r _r44_proposal; do
        [[ -z "$_r44_proposal" ]] && continue
        if grep -qE "affects_artefact:.*${_f44}" "$_r44_proposal" 2>/dev/null; then
          _accompanied=1
          break
        fi
      done <<< "$_r44_changed_reviews"
      if [[ $_accompanied -eq 0 ]]; then
        fail_rule "frozen_doc_edit_path_compliance" "$_f44 carries freeze_id but was modified without an accompanying docs/reviews/*.md proposal citing it under affects_artefact:"
        _r44_fail=1
      fi
    fi
  done <<< "$(printf "%b" "$_r44_frozen")"
fi
if [[ $_r44_fail -eq 0 ]]; then pass_rule "frozen_doc_edit_path_compliance"; fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [[ $fail_count -eq 0 ]]; then
  echo "GATE: PASS"
  exit 0
else
  echo "GATE: FAIL"
  exit 1
fi
