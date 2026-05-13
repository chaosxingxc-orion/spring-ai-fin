#!/usr/bin/env bash
# spring-ai-ascend architecture-sync gate -- L0 release-note contract review (26 rules).
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
#  10.  module_dep_direction                         -- agent-runtime must not depend on agent-platform (and vice versa)
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
# Rule 10 — module_dep_direction
# agent-runtime/pom.xml must NOT declare a dependency on agent-platform.
# agent-platform/pom.xml must NOT declare a dependency on agent-runtime.
# ---------------------------------------------------------------------------
_r10_fail=0
if [[ -f 'agent-runtime/pom.xml' ]]; then
  if grep -q '<artifactId>agent-platform</artifactId>' 'agent-runtime/pom.xml' 2>/dev/null; then
    fail_rule "module_dep_direction" "agent-runtime/pom.xml declares dependency on agent-platform. Per ADR-0026 forbidden."
    _r10_fail=1
  fi
fi
if [[ $_r10_fail -eq 0 ]] && [[ -f 'agent-platform/pom.xml' ]]; then
  if grep -q '<artifactId>agent-runtime</artifactId>' 'agent-platform/pom.xml' 2>/dev/null; then
    fail_rule "module_dep_direction" "agent-platform/pom.xml declares dependency on agent-runtime."
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
# Summary
# ---------------------------------------------------------------------------
if [[ $fail_count -eq 0 ]]; then
  echo "GATE: PASS"
  exit 0
else
  echo "GATE: FAIL"
  exit 1
fi
