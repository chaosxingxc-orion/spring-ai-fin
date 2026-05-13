#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-ascend architecture-sync gate (L0 release-note contract review, 26 rules).

.DESCRIPTION
  Exits 0 if all rules pass, 1 if any fail.
  Each rule prints PASS: <name> or FAIL: <name> -- <reason>.
  Prints GATE: PASS or GATE: FAIL at the end.

  Rules:
    1. status_enum_invalid                  -- architecture-status.yaml status values
    2. delivery_log_parity                  -- gate/log/*.json sha field matches filename
    3. eol_policy                           -- *.sh files in gate/ must be LF (not CRLF)
    4. ci_no_or_true_mask                   -- no gate/run_* || true in CI workflows
    5. required_files_present               -- contract-catalog.md and openapi-v1.yaml must exist
    6. metric_naming_namespace              -- springai_ascend_ prefix in Java metric names
    7. shipped_impl_paths_exist             -- every shipped: true implementation: path exists on disk
    8. no_hardcoded_versions_in_arch        -- module ARCHITECTURE.md files must not pin OSS versions inline
    9. openapi_path_consistency             -- /v3/api-docs must appear in WebSecurityConfig + platform ARCH
   10. module_dep_direction                 -- agent-runtime must not depend on agent-platform (and vice versa)
   11. shipped_envelope_fingerprint_present -- InMemoryCheckpointer enforces §4 #13 16-KiB cap (MAX_INLINE_PAYLOAD_BYTES present)
   12. inmemory_orchestrator_posture_guard_present -- SyncOrchestrator, InMemoryRunRegistry, InMemoryCheckpointer each contain AppPostureGate.requireDev (ADR-0035)
   13. contract_catalog_no_deleted_spi_or_starter_names -- contract-catalog.md must not reference deleted SPI interface names or deleted starter coords
   14. module_arch_method_name_truth        -- method names in ARCHITECTURE.md code-fences must exist in named Java class
   15. no_active_refs_deleted_wave_plan_paths -- active .md files must not reference docs/plans/engineering-plan-W0-W4.md or roadmap-W0-W4.md
   16. http_contract_w1_tenant_and_cancel_consistency -- W1 HTTP contract: no replace-X-Tenant-Id wording, no CREATED initial status, no DELETE cancel route
   17. contract_catalog_spi_table_matches_source -- SPI sub-table must list 7 known SPIs; OssApiProbe must not appear before Probes sub-table
   18. deleted_spi_starter_names_outside_catalog -- ACTIVE_NORMATIVE_DOCS corpus must not reference deleted SPI/starter names (widened, ADR-0043)
   19. shipped_row_tests_evidence           -- every shipped: true row must have non-empty tests: pointing to real files (ADR-0042, strengthened)
   20. module_metadata_truth               -- module README.md must not reference Java class names absent from the repo (ADR-0043)
   21. bom_glue_paths_exist                -- BoM must not contain known ghost implementation paths unless they exist on disk (ADR-0043)
   22. lowercase_metrics_in_contract_docs  -- ACTIVE_NORMATIVE_DOCS must not contain SPRINGAI_ASCEND_<lowercase> metric patterns (ADR-0043, widened)
   23. active_doc_internal_links_resolve   -- markdown links ](path) in active docs must resolve to existing files (ADR-0043)
   24. shipped_row_evidence_paths_exist    -- l2_documents: and latest_delivery_file: on shipped rows must exist on disk (ADR-0045)
   25. peripheral_wave_qualifier           -- SPI Javadoc and active docs must not name future-wave impls without wave qualifier (ADR-0045)
   26. release_note_shipped_surface_truth  -- docs/releases/*.md must not overclaim RunLifecycle as W0, invent RunContext.posture(), misattribute OpenAPI snapshot to ApiCompatibilityTest, or over-generalise AppPostureGate scope (ADR-0046)

.PARAMETER LocalOnly
  Not used by this script (kept for invocation parity with old version).
#>

[CmdletBinding()]
param(
  [switch]$LocalOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$failCount = 0

function Pass-Rule([string]$name) {
  Write-Host "PASS: $name"
}

function Fail-Rule([string]$name, [string]$reason) {
  Write-Host "FAIL: $name -- $reason"
  $script:failCount++
}

# ---------------------------------------------------------------------------
# Rule 1 — status_enum_invalid
# docs/governance/architecture-status.yaml status: values must be in the
# allowed enum. Any other value is a FAIL.
# ---------------------------------------------------------------------------
$statusPath = 'docs/governance/architecture-status.yaml'
$allowedStatus = @('design_accepted','implemented_unverified','test_verified','deferred_w1','deferred_w2')
$r1Fail = $false
if (Test-Path $statusPath) {
  $lines = Get-Content -LiteralPath $statusPath
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*status:\s*([A-Za-z_]+)\s*$') {
      $val = $matches[1]
      if (-not ($allowedStatus -contains $val)) {
        Fail-Rule 'status_enum_invalid' "status '$val' not in allowed enum {design_accepted,implemented_unverified,test_verified,deferred_w1,deferred_w2} in $statusPath"
        $r1Fail = $true
        break
      }
    }
  }
  if (-not $r1Fail) { Pass-Rule 'status_enum_invalid' }
} else {
  Fail-Rule 'status_enum_invalid' "$statusPath not found"
}

# ---------------------------------------------------------------------------
# Rule 2 — delivery_log_parity
# For each gate/log/*.json file: its sha field must equal the basename
# (without .json and platform suffix). Its semantic_pass must be a boolean.
# ---------------------------------------------------------------------------
$r2Fail = $false
$logFiles = Get-ChildItem -Path 'gate/log' -Filter '*.json' -File -ErrorAction SilentlyContinue
foreach ($lf in $logFiles) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($lf.Name)
  # Strip platform suffix to get sha
  $sha = $base -replace '-posix$','' -replace '-windows$',''
  # Skip non-sha filenames
  if ($sha -match '^self-test-' -or $sha -match '^operator-shape-') { continue }
  $raw = Get-Content -Raw -LiteralPath $lf.FullName
  $logSha = if ($raw -match '"sha":"([^"]+)"') { $matches[1] } else { '' }
  if ($logSha -ne $sha) {
    Fail-Rule 'delivery_log_parity' "log $($lf.Name): sha field '$logSha' != filename sha '$sha'"
    $r2Fail = $true
    break
  }
  $hasSemPass = $raw -match '"semantic_pass":(true|false)'
  if (-not $hasSemPass) {
    Fail-Rule 'delivery_log_parity' "log $($lf.Name) missing semantic_pass boolean field"
    $r2Fail = $true
    break
  }
}
if (-not $r2Fail) { Pass-Rule 'delivery_log_parity' }

# ---------------------------------------------------------------------------
# Rule 3 — eol_policy
# All *.sh files in gate/ must have LF line endings (not CRLF).
# Detect with PowerShell byte scan.
# ---------------------------------------------------------------------------
$r3Fail = $false
$shFiles = Get-ChildItem -Path 'gate' -Filter '*.sh' -File -ErrorAction SilentlyContinue
foreach ($shf in $shFiles) {
  $bytes = [System.IO.File]::ReadAllBytes($shf.FullName)
  $hasCr = $bytes -contains 13
  if ($hasCr) {
    Fail-Rule 'eol_policy' "$($shf.Name) contains CRLF; must be LF"
    $r3Fail = $true
    break
  }
}
if (-not $r3Fail) { Pass-Rule 'eol_policy' }

# ---------------------------------------------------------------------------
# Rule 4 — ci_no_or_true_mask
# .github/workflows/*.yml files must not contain gate/run_* invocations
# masked with || true.
# ---------------------------------------------------------------------------
$r4Fail = $false
$wfFiles = Get-ChildItem -Path '.github/workflows' -Filter '*.yml' -File -ErrorAction SilentlyContinue
foreach ($wf in $wfFiles) {
  $wfLines = Get-Content -LiteralPath $wf.FullName
  foreach ($wLine in $wfLines) {
    if ($wLine -match 'gate/run_' -and $wLine -match '\|\|\s*true') {
      Fail-Rule 'ci_no_or_true_mask' "$($wf.Name) contains gate/run_* masked with || true"
      $r4Fail = $true
      break
    }
  }
  if ($r4Fail) { break }
}
if (-not $r4Fail) { Pass-Rule 'ci_no_or_true_mask' }

# ---------------------------------------------------------------------------
# Rule 5 — required_files_present
# These 2 files must exist: docs/contracts/contract-catalog.md and
# docs/contracts/openapi-v1.yaml.
# ---------------------------------------------------------------------------
$r5Fail = $false
foreach ($req in @('docs/contracts/contract-catalog.md','docs/contracts/openapi-v1.yaml')) {
  if (-not (Test-Path $req)) {
    Fail-Rule 'required_files_present' "$req not found"
    $r5Fail = $true
  }
}
if (-not $r5Fail) { Pass-Rule 'required_files_present' }

# ---------------------------------------------------------------------------
# Rule 6 — metric_naming_namespace
# In *.java files under agent-platform/src and agent-runtime/src, any
# hardcoded metric name strings must start with springai_ascend_.
# Also no springai_fin_ prefix outside docs/archive/.
# ---------------------------------------------------------------------------
$r6Fail = $false
$javaRoots = @('agent-platform/src','agent-runtime/src') | Where-Object { Test-Path $_ }
$javaFiles = $javaRoots | ForEach-Object {
  Get-ChildItem -Path $_ -Filter '*.java' -Recurse -File -ErrorAction SilentlyContinue
}
foreach ($jf in $javaFiles) {
  # Check metric builder name literals
  $matches2 = Select-String -LiteralPath $jf.FullName `
    -Pattern '\.(counter|timer|gauge|summary)\("([^"]+)"' -AllMatches -ErrorAction SilentlyContinue
  foreach ($m in $matches2) {
    foreach ($hit in $m.Matches) {
      $mname = $hit.Groups[2].Value
      if ($mname -ne '' -and -not $mname.StartsWith('springai_ascend')) {
        Fail-Rule 'metric_naming_namespace' "metric name '$mname' in $($jf.FullName) does not use springai_ascend_ prefix"
        $r6Fail = $true
        break
      }
    }
    if ($r6Fail) { break }
  }
  if ($r6Fail) { break }
  # Check for residual springai_fin_ prefix
  $content = Get-Content -Raw -LiteralPath $jf.FullName
  if ($content -match 'springai_fin_|springai\.fin\.') {
    Fail-Rule 'metric_naming_namespace' "residual springai_fin_ or springai.fin. in $($jf.FullName)"
    $r6Fail = $true
    break
  }
}
if (-not $r6Fail) { Pass-Rule 'metric_naming_namespace' }

# ---------------------------------------------------------------------------
# Rule 7 — shipped_impl_paths_exist
# For every row in architecture-status.yaml where shipped: true, every
# implementation: path listed must exist on disk. Rows where implementation
# is null or empty are skipped.
# ---------------------------------------------------------------------------
$r7Fail = $false
if (Test-Path $statusPath) {
  $content7 = Get-Content -Raw -LiteralPath $statusPath
  # Find all shipped: true blocks, then find their implementation paths.
  # Strategy: scan line-by-line for implementation paths following a shipped: true.
  $lines7 = Get-Content -LiteralPath $statusPath
  $inShippedBlock = $false
  $inImplList = $false
  for ($i = 0; $i -lt $lines7.Count; $i++) {
    $ln = $lines7[$i]
    # Reset block tracking on a new top-level capability key (2-space indent + non-space key)
    if ($ln -match '^  [a-z][a-z_]+:') {
      $inShippedBlock = $false
      $inImplList = $false
    }
    if ($ln -match '^\s+shipped:\s+true') { $inShippedBlock = $true }
    if ($inShippedBlock -and $ln -match '^\s+implementation:') {
      # Check if inline null
      if ($ln -match 'implementation:\s*(null|\[\])') { $inImplList = $false; continue }
      $inImplList = $true
      continue
    }
    if ($inImplList -and $ln -match '^\s+-\s+(.+)$') {
      $implPath = $matches[1].Trim()
      if (-not (Test-Path -LiteralPath $implPath)) {
        Fail-Rule 'shipped_impl_paths_exist' "implementation path '$implPath' not found on disk (line $($i+1))"
        $r7Fail = $true
        break
      }
    } elseif ($inImplList -and $ln -notmatch '^\s+-') {
      $inImplList = $false
    }
  }
}
if (-not $r7Fail) { Pass-Rule 'shipped_impl_paths_exist' }

# ---------------------------------------------------------------------------
# Rule 8 — no_hardcoded_versions_in_arch
# Module-level ARCHITECTURE.md files must NOT contain inline OSS version pins
# like "3.5.x", "1.0.7 GA", "2.0.0-M5". These must say "see parent POM".
# Version strings in the root ARCHITECTURE.md table are allowed (they use
# "see parent POM" after the fourth-review cleanup).
# ---------------------------------------------------------------------------
$r8Fail = $false
$moduleArchFiles = @(
  'agent-platform/ARCHITECTURE.md',
  'agent-runtime/ARCHITECTURE.md'
)
# Pattern: a standalone version like "3.5.x", "1.0.7 GA", "2.0.0-M5", "1.35.0"
$versionPattern = '\b\d+\.\d+(\.\d+)?(\.x|-SNAPSHOT|-M\d+|-RC\d+|\s+GA)?\b'
foreach ($maf in $moduleArchFiles) {
  if (Test-Path $maf) {
    $mafContent = Get-Content -Raw -LiteralPath $maf
    # Look for version in a table column (pipe-delimited line with a version-like string)
    $tableLines = Select-String -InputObject $mafContent -Pattern '^\|.+\|\s*\d+\.\d+' -AllMatches
    if ($tableLines) {
      Fail-Rule 'no_hardcoded_versions_in_arch' "$maf contains inline version pins in a table. Use 'see parent POM' instead."
      $r8Fail = $true
      break
    }
  }
}
if (-not $r8Fail) { Pass-Rule 'no_hardcoded_versions_in_arch' }

# ---------------------------------------------------------------------------
# Rule 9 — openapi_path_consistency
# /v3/api-docs must appear in WebSecurityConfig.java requestMatchers() AND
# in agent-platform/ARCHITECTURE.md. This prevents the W0 doc/code drift
# where the doc said "/v3/api-docs not exposed" but the config permitted it.
# ---------------------------------------------------------------------------
$r9Fail = $false
$webSecPath = 'agent-platform/src/main/java/ascend/springai/platform/web/WebSecurityConfig.java'
$platformArchPath = 'agent-platform/ARCHITECTURE.md'
if (Test-Path $webSecPath) {
  $webSecContent = Get-Content -Raw -LiteralPath $webSecPath
  if ($webSecContent -notmatch '/v3/api-docs') {
    Fail-Rule 'openapi_path_consistency' "WebSecurityConfig.java does not permit /v3/api-docs. Update security config or gate."
    $r9Fail = $true
  }
}
if (-not $r9Fail -and (Test-Path $platformArchPath)) {
  $platformArchContent = Get-Content -Raw -LiteralPath $platformArchPath
  if ($platformArchContent -notmatch '/v3/api-docs') {
    Fail-Rule 'openapi_path_consistency' "agent-platform/ARCHITECTURE.md does not document /v3/api-docs exposure. Document it or remove the security permitAll."
    $r9Fail = $true
  }
}
if (-not $r9Fail) { Pass-Rule 'openapi_path_consistency' }

# ---------------------------------------------------------------------------
# Rule 10 — module_dep_direction
# agent-runtime/pom.xml must NOT declare a dependency on agent-platform.
# agent-platform/pom.xml must NOT declare a dependency on agent-runtime.
# This enforces the corrected module graph from ADR-0026.
# ---------------------------------------------------------------------------
$r10Fail = $false
$runtimePom = 'agent-runtime/pom.xml'
$platformPom = 'agent-platform/pom.xml'
if (Test-Path $runtimePom) {
  $rtContent = Get-Content -Raw -LiteralPath $runtimePom
  if ($rtContent -match '<artifactId>agent-platform</artifactId>') {
    Fail-Rule 'module_dep_direction' "agent-runtime/pom.xml declares dependency on agent-platform. Per ADR-0026 this is forbidden. Use agent-platform-contracts when a shared type is needed."
    $r10Fail = $true
  }
}
if (-not $r10Fail -and (Test-Path $platformPom)) {
  $pfContent = Get-Content -Raw -LiteralPath $platformPom
  if ($pfContent -match '<artifactId>agent-runtime</artifactId>') {
    Fail-Rule 'module_dep_direction' "agent-platform/pom.xml declares dependency on agent-runtime. This creates a circular or backwards dependency."
    $r10Fail = $true
  }
}
if (-not $r10Fail) { Pass-Rule 'module_dep_direction' }

# ---------------------------------------------------------------------------
# Rule 11 — shipped_envelope_fingerprint_present
# The payload_fingerprint_precommit capability is shipped: true in yaml.
# InMemoryCheckpointer.java MUST contain MAX_INLINE_PAYLOAD_BYTES to prove
# the §4 #13 16-KiB inline cap is actually enforced (not just documented).
# ---------------------------------------------------------------------------
$r11Fail = $false
$inMemoryCheckpointerPath = 'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryCheckpointer.java'
if (Test-Path -LiteralPath $inMemoryCheckpointerPath) {
  $cpContent = Get-Content -Raw -LiteralPath $inMemoryCheckpointerPath
  if ($cpContent -notmatch 'MAX_INLINE_PAYLOAD_BYTES') {
    Fail-Rule 'shipped_envelope_fingerprint_present' "InMemoryCheckpointer.java does not define MAX_INLINE_PAYLOAD_BYTES. §4 #13 16-KiB cap enforcement required (payload_fingerprint_precommit shipped: true)."
    $r11Fail = $true
  }
} else {
  Fail-Rule 'shipped_envelope_fingerprint_present' "$inMemoryCheckpointerPath not found on disk."
  $r11Fail = $true
}
if (-not $r11Fail) { Pass-Rule 'shipped_envelope_fingerprint_present' }

# ---------------------------------------------------------------------------
# Rule 12 — inmemory_orchestrator_posture_guard_present
# ADR-0035: AppPostureGate.requireDevForInMemoryComponent is the single
# construction path for posture reads (Rule 6). All three in-memory components
# MUST contain the literal AppPostureGate.requireDev in their source.
# ---------------------------------------------------------------------------
$r12Fail = $false
$postureGuardTargets = @(
  'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/SyncOrchestrator.java',
  'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryRunRegistry.java',
  'agent-runtime/src/main/java/ascend/springai/runtime/orchestration/inmemory/InMemoryCheckpointer.java'
)
foreach ($target in $postureGuardTargets) {
  if (Test-Path -LiteralPath $target) {
    $tc = Get-Content -Raw -LiteralPath $target
    if ($tc -notmatch 'AppPostureGate\.requireDev') {
      Fail-Rule 'inmemory_orchestrator_posture_guard_present' "$target does not call AppPostureGate.requireDev*. Per ADR-0035 all in-memory components must delegate posture reads to AppPostureGate (Rule 6 single-construction-path)."
      $r12Fail = $true
    }
  } else {
    Fail-Rule 'inmemory_orchestrator_posture_guard_present' "$target not found on disk."
    $r12Fail = $true
  }
}
if (-not $r12Fail) { Pass-Rule 'inmemory_orchestrator_posture_guard_present' }

# ---------------------------------------------------------------------------
# Rule 13 — contract_catalog_no_deleted_spi_or_starter_names
# ADR-0036: contract-catalog.md must not reference deleted SPI interface names
# or deleted starter artifact coordinates. These were removed in the 2026-05-12
# Occam pass. Any lingering reference is a contract-surface truth violation.
# ---------------------------------------------------------------------------
$r13Fail = $false
$catalogPath = 'docs/contracts/contract-catalog.md'
$deletedNames = @(
  'LongTermMemoryRepository',
  'ToolProvider',
  'LayoutParser',
  'DocumentSourceConnector',
  'PolicyEvaluator',
  'IdempotencyRepository',
  'ArtifactRepository',
  'spring-ai-ascend-memory-starter',
  'spring-ai-ascend-skills-starter',
  'spring-ai-ascend-knowledge-starter',
  'spring-ai-ascend-governance-starter',
  'spring-ai-ascend-persistence-starter',
  'spring-ai-ascend-resilience-starter',
  'spring-ai-ascend-mem0-starter',
  'spring-ai-ascend-docling-starter',
  'spring-ai-ascend-langchain4j-profile'
)
if (Test-Path -LiteralPath $catalogPath) {
  $catalogContent = Get-Content -Raw -LiteralPath $catalogPath
  foreach ($deleted in $deletedNames) {
    if ($catalogContent -match [regex]::Escape($deleted)) {
      Fail-Rule 'contract_catalog_no_deleted_spi_or_starter_names' "$catalogPath references deleted name '$deleted'. Per ADR-0036 Gate Rule 13 this is a contract-surface truth violation."
      $r13Fail = $true
    }
  }
} else {
  Fail-Rule 'contract_catalog_no_deleted_spi_or_starter_names' "$catalogPath not found."
  $r13Fail = $true
}
if (-not $r13Fail) { Pass-Rule 'contract_catalog_no_deleted_spi_or_starter_names' }

# ---------------------------------------------------------------------------
# Rule 14 — module_arch_method_name_truth
# ADR-0036: method names in code-fence blocks in agent-platform/ARCHITECTURE.md
# and agent-runtime/ARCHITECTURE.md must exist in the named Java class.
# Pragmatic regex sweep: looks for probe.probe() and other named method refs.
# Currently checks the specific known drift: probe.check() was wrong; correct
# is probe.probe(). Fails if probe.check() appears in any module ARCHITECTURE.md.
# ---------------------------------------------------------------------------
$r14Fail = $false
$moduleArchFiles = @(
  'agent-platform/ARCHITECTURE.md',
  'agent-runtime/ARCHITECTURE.md'
)
foreach ($archFile in $moduleArchFiles) {
  if (Test-Path -LiteralPath $archFile) {
    $archContent = Get-Content -Raw -LiteralPath $archFile
    if ($archContent -match 'probe\.check\(\)') {
      Fail-Rule 'module_arch_method_name_truth' "$archFile references probe.check() but the actual method in OssApiProbe is probe.probe(). Per ADR-0036 Gate Rule 14 method names in docs must match source."
      $r14Fail = $true
    }
  }
}
if (-not $r14Fail) { Pass-Rule 'module_arch_method_name_truth' }

# ---------------------------------------------------------------------------
# Rule 15 — no_active_refs_deleted_wave_plan_paths
# ADR-0041: active .md files (outside archive/reviews/third_party/target/.git)
# must not reference docs/plans/engineering-plan-W0-W4.md or
# docs/plans/roadmap-W0-W4.md. Both plans were archived to
# docs/archive/2026-05-13-plans-archived/ per ADR-0037.
# ---------------------------------------------------------------------------
$r15Fail = $false
$deletedPlanRefs = @('docs/plans/engineering-plan-W0-W4.md', 'docs/plans/roadmap-W0-W4.md')
$activeMdFiles15 = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $p = $_.FullName.Replace('\', '/')
    $p -notmatch '/docs/archive/' -and $p -notmatch '/docs/reviews/' -and
    $p -notmatch '/docs/adr/' -and $p -notmatch '/docs/delivery/' -and
    $p -notmatch '/docs/v6-rationale/' -and
    $p -notmatch '/third_party/' -and $p -notmatch '/target/' -and $p -notmatch '/\.git/'
  }
foreach ($mdFile in $activeMdFiles15) {
  $content15 = Get-Content -Raw -LiteralPath $mdFile.FullName -ErrorAction SilentlyContinue
  foreach ($ref in $deletedPlanRefs) {
    if ($content15 -match [regex]::Escape($ref)) {
      Fail-Rule 'no_active_refs_deleted_wave_plan_paths' "$($mdFile.FullName) references deleted plan path '$ref'. Per ADR-0041 Gate Rule 15 active docs must not reference archived plan paths. Use docs/archive/2026-05-13-plans-archived/ if historical reference is needed."
      $r15Fail = $true
      break
    }
  }
  if ($r15Fail) { break }
}
if (-not $r15Fail) { Pass-Rule 'no_active_refs_deleted_wave_plan_paths' }

# ---------------------------------------------------------------------------
# Rule 16 — http_contract_w1_tenant_and_cancel_consistency
# ADR-0040: Three W1 HTTP contract invariants:
# (a) No "replace.*X-Tenant-Id" wording in active docs — W1 adds JWT cross-check,
#     does not replace the header.
# (b) http-api-contracts.md must not reference CREATED as initial run status —
#     correct initial status is PENDING (RunStatus enum has no CREATED).
# (c) openapi-v1.yaml must not mention DELETE /v1/runs/{runId} as cancel —
#     cancel is POST /v1/runs/{id}/cancel per Rule 20 RunStateMachine.
# ---------------------------------------------------------------------------
$r16Fail = $false
# 16a: no forward-looking "will replace X-Tenant-Id" claim in active normative docs
# Exclude docs/adr/: ADRs may legitimately document rejected options and past wrong text.
$activeMdFiles16 = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $p = $_.FullName.Replace('\', '/')
    $p -notmatch '/docs/archive/' -and $p -notmatch '/docs/reviews/' -and
    $p -notmatch '/docs/adr/' -and $p -notmatch '/third_party/' -and
    $p -notmatch '/target/' -and $p -notmatch '/\.git/'
  }
foreach ($mdFile in $activeMdFiles16) {
  $c16 = Get-Content -Raw -LiteralPath $mdFile.FullName -ErrorAction SilentlyContinue
  if ($c16 -cmatch 'TenantContextFilter\s+(switches\s+to|replaces?\s+(with\s+)?JWT|moves\s+to)\s+JWT|will\s+replace.*X-Tenant-Id|replace\s+header-based.*with\s+JWT|W1\s+replaces.*X-Tenant-Id') {
    Fail-Rule 'http_contract_w1_tenant_and_cancel_consistency' "$($mdFile.FullName) contains a replacement-implying claim about X-Tenant-Id or TenantContextFilter. Per ADR-0040 W1 adds JWT cross-check; X-Tenant-Id is NOT replaced. Forbidden phrasings: 'switches to JWT', 'replaces with JWT', 'moves to JWT', 'will replace X-Tenant-Id'."
    $r16Fail = $true
    break
  }
}
# 16b: http-api-contracts.md must not say CREATED as initial status
if (-not $r16Fail) {
  $httpContractsPath = 'docs/contracts/http-api-contracts.md'
  if (Test-Path $httpContractsPath) {
    $hc16 = Get-Content -Raw -LiteralPath $httpContractsPath
    if ($hc16 -match 'starts in CREATED|CREATED stage|status.*CREATED') {
      Fail-Rule 'http_contract_w1_tenant_and_cancel_consistency' "$httpContractsPath references CREATED as initial run status. Per ADR-0040 initial status is PENDING."
      $r16Fail = $true
    }
  }
}
# 16c: openapi-v1.yaml must not mention DELETE /v1/runs/{runId} as cancel mechanism
if (-not $r16Fail) {
  $openapiPath16 = 'docs/contracts/openapi-v1.yaml'
  if (Test-Path $openapiPath16) {
    $oc16 = Get-Content -Raw -LiteralPath $openapiPath16
    if ($oc16 -match 'DELETE\s*/v1/runs/\{runId\}|DELETE.*runId.*cancel') {
      Fail-Rule 'http_contract_w1_tenant_and_cancel_consistency' "$openapiPath16 references DELETE /v1/runs/{runId} as cancel mechanism. Per ADR-0040 cancel is POST /v1/runs/{id}/cancel."
      $r16Fail = $true
    }
  }
}
if (-not $r16Fail) { Pass-Rule 'http_contract_w1_tenant_and_cancel_consistency' }

# ---------------------------------------------------------------------------
# Rule 17 — contract_catalog_spi_table_matches_source
# ADR-0041: The SPI sub-table in contract-catalog.md must list the 7 known
# active SPI interfaces. OssApiProbe must NOT appear before the **Probes
# sub-table heading — it is a probe, not an SPI.
# ---------------------------------------------------------------------------
$r17Fail = $false
$catalogPath17 = 'docs/contracts/contract-catalog.md'
$knownSpiNames = @('RunRepository','Checkpointer','GraphMemoryRepository','ResilienceContract','Orchestrator','GraphExecutor','AgentLoopExecutor')
if (Test-Path $catalogPath17) {
  $cat17 = Get-Content -Raw -LiteralPath $catalogPath17
  foreach ($spi in $knownSpiNames) {
    if ($cat17 -notmatch [regex]::Escape($spi)) {
      Fail-Rule 'contract_catalog_spi_table_matches_source' "$catalogPath17 does not list SPI '$spi'. Per ADR-0041 Gate Rule 17 all 7 active SPI interfaces must appear in the contract catalog."
      $r17Fail = $true
    }
  }
  if (-not $r17Fail) {
    $lines17 = Get-Content -LiteralPath $catalogPath17
    $pastProbesHeader = $false
    foreach ($ln17 in $lines17) {
      if ($ln17 -match '\*\*Probes' -or $ln17 -match '^#+\s+Probes') { $pastProbesHeader = $true }
      if (-not $pastProbesHeader -and $ln17 -match 'OssApiProbe') {
        Fail-Rule 'contract_catalog_spi_table_matches_source' "$catalogPath17 contains OssApiProbe before the **Probes sub-table. OssApiProbe is a probe, not an SPI. Per ADR-0041 Gate Rule 17 it must appear only in the Probes sub-table."
        $r17Fail = $true
        break
      }
    }
  }
  # ADR-0044 extension: RunContext row in data-carriers sub-table must contain 'interface'
  if (-not $r17Fail) {
    $inDataCarriers17 = $false
    $runContextFound17 = $false
    $runContextHasInterface17 = $false
    foreach ($ln17x in (Get-Content -LiteralPath $catalogPath17)) {
      if ($ln17x -match '\*\*Data carriers') { $inDataCarriers17 = $true }
      if ($inDataCarriers17 -and $ln17x -match 'RunContext') {
        $runContextFound17 = $true
        if ($ln17x -match 'interface') { $runContextHasInterface17 = $true }
        break
      }
    }
    if ($runContextFound17 -and -not $runContextHasInterface17) {
      Fail-Rule 'contract_catalog_spi_table_matches_source' "$catalogPath17 RunContext row in data-carriers sub-table does not contain 'interface'. Per ADR-0044 Gate Rule 17 extension RunContext must be classified as interface (not record)."
      $r17Fail = $true
    }
  }
} else {
  Fail-Rule 'contract_catalog_spi_table_matches_source' "$catalogPath17 not found."
  $r17Fail = $true
}
if (-not $r17Fail) { Pass-Rule 'contract_catalog_spi_table_matches_source' }

# ---------------------------------------------------------------------------
# Rule 18 — deleted_spi_starter_names_outside_catalog
# ADR-0041 extends Rule 13: the same deleted SPI/starter names must not appear
# in third_party/MANIFEST.md, docs/cross-cutting/oss-bill-of-materials.md,
# or README.md. These files are outside contract-catalog.md but are part of
# the active normative corpus.
# ---------------------------------------------------------------------------
$r18Fail = $false
$deletedNames18 = @(
  'LongTermMemoryRepository', 'ToolProvider', 'LayoutParser', 'DocumentSourceConnector',
  'PolicyEvaluator', 'IdempotencyRepository', 'ArtifactRepository',
  'spring-ai-ascend-memory-starter', 'spring-ai-ascend-skills-starter',
  'spring-ai-ascend-knowledge-starter', 'spring-ai-ascend-governance-starter',
  'spring-ai-ascend-persistence-starter', 'spring-ai-ascend-resilience-starter',
  'spring-ai-ascend-mem0-starter', 'spring-ai-ascend-docling-starter',
  'spring-ai-ascend-langchain4j-profile'
)
# Widened to full ACTIVE_NORMATIVE_DOCS corpus (ADR-0043)
$r18ActiveFiles = Get-ChildItem -Path $repoRoot -Recurse -Include '*.md','*.yaml' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $p = $_.FullName.Replace('\', '/')
    $p -notmatch '/docs/archive/' -and $p -notmatch '/docs/reviews/' -and
    $p -notmatch '/docs/adr/' -and $p -notmatch '/docs/delivery/' -and
    $p -notmatch '/docs/v6-rationale/' -and $p -notmatch '/docs/plans/' -and
    $p -notmatch '/third_party/' -and $p -notmatch '/target/' -and
    $p -notmatch '/\.git/'
  }
foreach ($target18 in $r18ActiveFiles) {
  $tc18 = Get-Content -Raw -LiteralPath $target18.FullName -ErrorAction SilentlyContinue
  foreach ($dn18 in $deletedNames18) {
    if ($tc18 -match [regex]::Escape($dn18)) {
      Fail-Rule 'deleted_spi_starter_names_outside_catalog' "$($target18.FullName) references deleted name '$dn18'. Per ADR-0043 Gate Rule 18 (widened) this is a contract-surface truth violation."
      $r18Fail = $true
    }
  }
}
if (-not $r18Fail) { Pass-Rule 'deleted_spi_starter_names_outside_catalog' }

# ---------------------------------------------------------------------------
# Rule 19 — shipped_row_tests_evidence (strengthened per ADR-0042 + ADR-0045)
# Every shipped: true row must have:
#   (a) tests: key present (not absent),
#   (b) tests: non-empty (not [] and not block-empty),
#   (c) every listed test path exists on disk.
# ---------------------------------------------------------------------------
$r19Fail = $false
if (Test-Path $statusPath) {
  $yamlLines19 = Get-Content -LiteralPath $statusPath
  $currentKey19 = ''; $inShippedBlock19 = $false
  $inTestsList19 = $false; $testsFound19 = $false
  $testsHasItems19 = $false; $currentTestPaths19 = [System.Collections.Generic.List[string]]::new()

  foreach ($i19 in 0..($yamlLines19.Count)) {
    $line19 = if ($i19 -lt $yamlLines19.Count) { $yamlLines19[$i19] } else { '  __sentinel__:' }

    if ($line19 -cmatch '^  [a-z][a-z_]+:') {
      # Flush previous shipped block before moving to next capability
      if ($inShippedBlock19) {
        if (-not $testsFound19) {
          Fail-Rule 'shipped_row_tests_evidence' "$statusPath capability '$currentKey19' shipped:true but tests: key absent. Per ADR-0042 Gate Rule 19 all shipped rows must have non-empty test evidence."
          $r19Fail = $true
        } elseif (-not $testsHasItems19) {
          Fail-Rule 'shipped_row_tests_evidence' "$statusPath capability '$currentKey19' shipped:true but tests: is empty ([] or no items). Per ADR-0042 Gate Rule 19 all shipped rows must have non-empty test evidence."
          $r19Fail = $true
        } else {
          foreach ($tp19 in $currentTestPaths19) {
            if (-not (Test-Path -LiteralPath $tp19)) {
              Fail-Rule 'shipped_row_tests_evidence' "$statusPath capability '$currentKey19' lists test path '$tp19' not found on disk. Per ADR-0042 Gate Rule 19 all test paths must resolve."
              $r19Fail = $true
            }
          }
        }
      }
      $currentKey19 = ($line19.Trim() -replace ':.*', '')
      $inShippedBlock19 = $false; $inTestsList19 = $false
      $testsFound19 = $false; $testsHasItems19 = $false
      $currentTestPaths19 = [System.Collections.Generic.List[string]]::new()
      continue
    }
    if ($line19 -cmatch '^\s+shipped:\s+true') { $inShippedBlock19 = $true }
    if ($inShippedBlock19) {
      if ($line19 -cmatch '^\s+tests:\s*\[\]') { $testsFound19 = $true; $inTestsList19 = $false }
      elseif ($line19 -cmatch '^\s+tests:\s*$') { $testsFound19 = $true; $inTestsList19 = $true }
      elseif ($line19 -cmatch '^\s+tests:') { $testsFound19 = $true; $inTestsList19 = $false }
      elseif ($inTestsList19 -and $line19 -cmatch '^\s+-\s+(.+)$') {
        $testsHasItems19 = $true
        $currentTestPaths19.Add($Matches[1].Trim())
      } elseif ($inTestsList19 -and $line19 -notmatch '^\s+-') { $inTestsList19 = $false }
    }
  }
}
if (-not $r19Fail) { Pass-Rule 'shipped_row_tests_evidence' }

# ---------------------------------------------------------------------------
# Rule 20 — module_metadata_truth
# ADR-0043: module README.md files must not reference Java class names that
# do not exist in the repository.
# ---------------------------------------------------------------------------
$r20Fail = $false
$ghostClasses20 = @('GraphitiRestGraphMemoryRepository', 'CogneeGraphMemoryRepository')
$moduleReadmes20 = Get-ChildItem -Path $repoRoot -Recurse -Filter 'README.md' -File -ErrorAction SilentlyContinue |
  Where-Object { $p = $_.FullName.Replace('\','/'); $p -notmatch '/docs/' -and $p -notmatch '/third_party/' -and $p -notmatch '/target/' }
foreach ($rmFile in $moduleReadmes20) {
  $rmContent = Get-Content -Raw -LiteralPath $rmFile.FullName -ErrorAction SilentlyContinue
  foreach ($ghostClass in $ghostClasses20) {
    if ($rmContent -match [regex]::Escape($ghostClass)) {
      $classFile = Get-ChildItem -Path $repoRoot -Recurse -Filter "$ghostClass.java" -ErrorAction SilentlyContinue | Select-Object -First 1
      if (-not $classFile) {
        Fail-Rule 'module_metadata_truth' "$($rmFile.FullName) references class '$ghostClass' but no .java file exists. Per ADR-0043 Gate Rule 20 module READMEs must not reference non-existent Java classes."
        $r20Fail = $true
      }
    }
  }
}
if (-not $r20Fail) { Pass-Rule 'module_metadata_truth' }

# ---------------------------------------------------------------------------
# Rule 21 — bom_glue_paths_exist
# ADR-0043: docs/cross-cutting/oss-bill-of-materials.md must not contain the
# known ghost implementation paths unless the path exists on disk.
# ---------------------------------------------------------------------------
$r21Fail = $false
$bomPath21 = 'docs/cross-cutting/oss-bill-of-materials.md'
$ghostPaths21 = @(
  'agent-runtime/llm/ChatClientFactory', 'agent-runtime/llm/LlmRouter',
  'agent-runtime/memory/PgVectorAdapter', 'agent-runtime/temporal/RunWorkflow',
  'agent-runtime/tool/McpToolRegistry'
)
if (Test-Path $bomPath21) {
  $bomContent21 = Get-Content -Raw -LiteralPath $bomPath21
  foreach ($gp21 in $ghostPaths21) {
    if ($bomContent21 -match [regex]::Escape($gp21)) {
      $gpFull21 = Join-Path $repoRoot ($gp21.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
      if (-not (Test-Path $gpFull21)) {
        Fail-Rule 'bom_glue_paths_exist' "$bomPath21 references path '$gp21' which does not exist on disk. Per ADR-0043 Gate Rule 21 BoM glue paths must exist or be removed."
        $r21Fail = $true
      }
    }
  }
}
if (-not $r21Fail) { Pass-Rule 'bom_glue_paths_exist' }

# ---------------------------------------------------------------------------
# Rule 22 — lowercase_metrics_in_contract_docs (widened + case-sensitive fix)
# ADR-0043: the full ACTIVE_NORMATIVE_DOCS corpus must not contain
# SPRINGAI_ASCEND_<lowercase> metric name patterns. Case-SENSITIVE check
# (use -cmatch to avoid PowerShell's default case-insensitive -match).
# ---------------------------------------------------------------------------
$r22Fail = $false
$activeFiles22 = Get-ChildItem -Path $repoRoot -Recurse -Include '*.md','*.yaml' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $p = $_.FullName.Replace('\', '/')
    $p -notmatch '/docs/archive/' -and $p -notmatch '/docs/reviews/' -and
    $p -notmatch '/docs/adr/' -and $p -notmatch '/docs/delivery/' -and
    $p -notmatch '/docs/v6-rationale/' -and $p -notmatch '/docs/plans/' -and
    $p -notmatch '/third_party/' -and $p -notmatch '/target/' -and
    $p -notmatch '/\.git/'
  }
foreach ($af22 in $activeFiles22) {
  $content22 = Get-Content -Raw -LiteralPath $af22.FullName -ErrorAction SilentlyContinue
  if ($content22 -cmatch 'SPRINGAI_ASCEND_[a-z]') {
    Fail-Rule 'lowercase_metrics_in_contract_docs' "$($af22.FullName) contains uppercase metric namespace 'SPRINGAI_ASCEND_<lowercase>'. Per ADR-0043 Gate Rule 22 (widened) metric names must use lowercase springai_ascend_ prefix."
    $r22Fail = $true
  }
}
if (-not $r22Fail) { Pass-Rule 'lowercase_metrics_in_contract_docs' }

# ---------------------------------------------------------------------------
# Rule 23 — active_doc_internal_links_resolve
# ADR-0043: markdown links ](relative-path) in active normative docs must
# resolve to files that exist on disk. Excludes http://, https://, anchors.
# ---------------------------------------------------------------------------
$r23Fail = $false
$activeFiles23 = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $p = $_.FullName.Replace('\', '/')
    $p -notmatch '/docs/archive/' -and $p -notmatch '/docs/reviews/' -and
    $p -notmatch '/docs/adr/' -and $p -notmatch '/docs/delivery/' -and
    $p -notmatch '/docs/v6-rationale/' -and $p -notmatch '/docs/plans/' -and
    $p -notmatch '/third_party/' -and $p -notmatch '/target/' -and
    $p -notmatch '/\.git/'
  }
foreach ($af23 in $activeFiles23) {
  $content23 = Get-Content -Raw -LiteralPath $af23.FullName -ErrorAction SilentlyContinue
  $linkMatches23 = [regex]::Matches($content23, '\]\(([^)]+)\)')
  foreach ($lm23 in $linkMatches23) {
    $target23 = $lm23.Groups[1].Value.Trim()
    if ($target23 -match '^https?://' -or $target23 -match '^#' -or $target23 -match '^mailto:') { continue }
    $targetPath23 = ($target23 -replace '#[^#]*$', '').Trim()
    if ($targetPath23 -eq '') { continue }
    $fileDir23 = Split-Path -Parent $af23.FullName
    $resolved23 = [System.IO.Path]::GetFullPath((Join-Path $fileDir23 $targetPath23))
    if (-not (Test-Path -LiteralPath $resolved23)) {
      Fail-Rule 'active_doc_internal_links_resolve' "$($af23.FullName) has broken link to '$target23' (resolved: '$resolved23'). Per ADR-0043 Gate Rule 23 all internal links in active docs must resolve."
      $r23Fail = $true
    }
  }
}
if (-not $r23Fail) { Pass-Rule 'active_doc_internal_links_resolve' }

# ---------------------------------------------------------------------------
# Rule 24 — shipped_row_evidence_paths_exist
# ADR-0045: every l2_documents: entry and latest_delivery_file: value on a
# shipped: true row must resolve to an existing file on disk. Closes the
# REF-DRIFT pattern where references are syntactically valid but point at
# non-existent artifacts. (implementation: covered by Rule 7; tests: by Rule 19.)
# ---------------------------------------------------------------------------
$r24Fail = $false
if (Test-Path $statusPath) {
  $yamlLines24 = Get-Content -LiteralPath $statusPath
  $currentKey24 = ''; $inShippedBlock24 = $false; $inL2List24 = $false

  foreach ($i24 in 0..($yamlLines24.Count)) {
    $line24 = if ($i24 -lt $yamlLines24.Count) { $yamlLines24[$i24] } else { '  __sentinel__:' }

    if ($line24 -cmatch '^  [a-z][a-z_]+:') {
      $currentKey24 = ($line24.Trim() -replace ':.*', '')
      $inShippedBlock24 = $false; $inL2List24 = $false
    }
    if ($line24 -cmatch '^\s+shipped:\s+true') { $inShippedBlock24 = $true }
    if ($inShippedBlock24) {
      if ($line24 -cmatch '^\s+latest_delivery_file:\s+(.+)$') {
        $ldf24 = $Matches[1].Trim()
        if ($ldf24 -and -not (Test-Path -LiteralPath $ldf24)) {
          Fail-Rule 'shipped_row_evidence_paths_exist' "$statusPath capability '$currentKey24' latest_delivery_file '$ldf24' not found on disk. Per ADR-0045 Gate Rule 24 all shipped-row evidence paths must resolve."
          $r24Fail = $true
        }
      }
      if ($line24 -cmatch '^\s+l2_documents:\s*\[\]') { $inL2List24 = $false }
      elseif ($line24 -cmatch '^\s+l2_documents:\s*$') { $inL2List24 = $true }
      elseif ($line24 -cmatch '^\s+l2_documents:') { $inL2List24 = $false }
      elseif ($inL2List24 -and $line24 -cmatch '^\s+-\s+(.+)$') {
        $l2p24 = $Matches[1].Trim()
        if ($l2p24 -and -not (Test-Path -LiteralPath $l2p24)) {
          Fail-Rule 'shipped_row_evidence_paths_exist' "$statusPath capability '$currentKey24' l2_documents entry '$l2p24' not found on disk. Per ADR-0045 Gate Rule 24 all shipped-row evidence paths must resolve."
          $r24Fail = $true
        }
      } elseif ($inL2List24 -and $line24 -notmatch '^\s+-') { $inL2List24 = $false }
    }
  }
}
if (-not $r24Fail) { Pass-Rule 'shipped_row_evidence_paths_exist' }

# ---------------------------------------------------------------------------
# Rule 25 — peripheral_wave_qualifier
# ADR-0045: SPI Javadoc in agent-runtime/src/main/java must not use
# "Primary sidecar impl:" or "Primary impl:" without a wave qualifier
# (W0/W1/W2/W3/W4) in the surrounding context. Active markdown docs must
# not use "Sidecar adapter —" without a wave qualifier or ADR reference.
# Closes the PERIPHERAL-DRIFT pattern at gate level.
# ---------------------------------------------------------------------------
$r25Fail = $false
# 25a: SPI Java source
$spiJavaFiles25 = Get-ChildItem -Path 'agent-runtime/src/main/java' -Filter '*.java' -Recurse -File -ErrorAction SilentlyContinue
foreach ($sf25 in $spiJavaFiles25) {
  $lines25j = Get-Content -LiteralPath $sf25.FullName -ErrorAction SilentlyContinue
  for ($j25 = 0; $j25 -lt $lines25j.Count; $j25++) {
    if ($lines25j[$j25] -cmatch 'Primary sidecar impl:|Primary impl:') {
      $lo = [Math]::Max(0, $j25 - 2); $hi = [Math]::Min($lines25j.Count - 1, $j25 + 3)
      $ctx25 = ($lines25j[$lo..$hi] -join ' ')
      if ($ctx25 -notmatch '\bW[0-4]\b') {
        Fail-Rule 'peripheral_wave_qualifier' "$($sf25.FullName):$($j25+1) contains 'Primary.*impl:' without wave qualifier (W0-W4) in surrounding context. Per ADR-0045 Gate Rule 25 future-wave impl claims must carry wave qualifiers."
        $r25Fail = $true
      }
    }
  }
}
# 25b: active markdown docs
$activeMdFiles25 = Get-ChildItem -Path $repoRoot -Recurse -Filter '*.md' -File -ErrorAction SilentlyContinue |
  Where-Object {
    $p = $_.FullName.Replace('\', '/')
    $p -notmatch '/docs/archive/' -and $p -notmatch '/docs/reviews/' -and
    $p -notmatch '/docs/adr/' -and $p -notmatch '/docs/delivery/' -and
    $p -notmatch '/docs/v6-rationale/' -and $p -notmatch '/docs/plans/' -and
    $p -notmatch '/third_party/' -and $p -notmatch '/target/' -and $p -notmatch '/\.git/'
  }
foreach ($af25 in $activeMdFiles25) {
  $lines25m = Get-Content -LiteralPath $af25.FullName -ErrorAction SilentlyContinue
  for ($k25 = 0; $k25 -lt $lines25m.Count; $k25++) {
    $ln25 = $lines25m[$k25]
    if ($ln25 -cmatch 'Sidecar adapter —|Primary sidecar impl:') {
      if ($ln25 -notmatch '\bW[0-4]\b' -and $ln25 -notmatch 'ADR-') {
        Fail-Rule 'peripheral_wave_qualifier' "$($af25.FullName):$($k25+1) contains 'Sidecar adapter —' or 'Primary sidecar impl:' without wave qualifier or ADR reference. Per ADR-0045 Gate Rule 25 future-wave impl claims must carry wave qualifiers."
        $r25Fail = $true
      }
    }
  }
}
if (-not $r25Fail) { Pass-Rule 'peripheral_wave_qualifier' }

# ---------------------------------------------------------------------------
# Rule 26 — release_note_shipped_surface_truth
# ADR-0046: docs/releases/*.md must not overclaim shipped surfaces.
#   26a — RunLifecycle name guard: a line containing 'RunLifecycle' MUST be in a one-line
#         context window (line i-1, i, i+1) that contains a wave qualifier W1/W2/W3/W4, OR
#         the same line must contain one of: design-only, deferred, not shipped,
#         remains design, materialised at W.
#   26b — RunContext method-list guard: a line listing RunContext methods MUST NOT contain
#         posture() and method-name tokens must be a subset of
#         {runId, tenantId, checkpointer, suspendForChild}.
#   26c — OpenAPI snapshot attribution: a line co-mentioning ApiCompatibilityTest with
#         snapshot|OpenAPI.*spec|diverges fails — actual snapshot test is OpenApiContractIT.
#   26d — AppPostureGate scope guard: 'AppPostureGate' on a line with 'HTTP Edge' fails
#         (placement error); 'all runtime components.*posture.*constructor' fails (breadth).
# Closes GATE-SCOPE-GAP for release artifact class.
# ---------------------------------------------------------------------------
$r26Fail = $false
$releasesDir = Join-Path $repoRoot 'docs/releases'
if (Test-Path $releasesDir) {
  $releaseFiles26 = Get-ChildItem -Path $releasesDir -Filter '*.md' -File -ErrorAction SilentlyContinue
  foreach ($rf26 in $releaseFiles26) {
    $lines26 = Get-Content -LiteralPath $rf26.FullName -ErrorAction SilentlyContinue
    if ($null -eq $lines26) { continue }
    for ($i26 = 0; $i26 -lt $lines26.Count; $i26++) {
      $line26 = $lines26[$i26]
      # --- Narrative exemption: lines that explicitly describe Rule 26 itself are meta,
      # not shipped-surface claims. Authors intentionally referencing the rule for
      # documentation purposes are allowed to mention forbidden tokens.
      if ($line26 -cmatch 'Gate Rule 26|ADR-0046|release_note_shipped_surface_truth') {
        continue
      }
      # --- 26a: RunLifecycle name guard ---
      if ($line26 -cmatch 'RunLifecycle') {
        $lo26 = [Math]::Max(0, $i26 - 1); $hi26 = [Math]::Min($lines26.Count - 1, $i26 + 1)
        $ctx26a = ($lines26[$lo26..$hi26] -join ' ')
        $hasWave26a = $ctx26a -cmatch '\bW[1-4]\b'
        $hasDeferMarker26a = $line26 -cmatch 'design-only|deferred|not shipped|remains design|materialised at W|materialized at W'
        if (-not $hasWave26a -and -not $hasDeferMarker26a) {
          Fail-Rule 'release_note_shipped_surface_truth' "$($rf26.FullName):$($i26+1) (26a) contains 'RunLifecycle' without a W1-W4 wave qualifier in context window or design-only/deferred/not shipped/remains design marker on the same line. Per ADR-0046 RunLifecycle is W2 design-only; the release note must qualify it."
          $r26Fail = $true
        }
      }
      # --- 26b: RunContext method-list guard ---
      # Only fires on lines where RunContext appears in a methods-context: markdown table
      # cell header, methods verb ("exposes"/"interface"/"methods"/"provides"/"carries"/"has"),
      # or RunContext.method( direct-call syntax. Otherwise lines mentioning RunContext only
      # in passing (e.g. disclaimers, cross-references) are skipped to avoid catching method
      # calls owned by other classes on the same line (e.g. AppPostureGate.requireDev(...)).
      if ($line26 -cmatch 'RunContext') {
        $isMethodsCtx26b = ($line26 -cmatch '\|\s*`?RunContext`?\s*\|') -or `
                          ($line26 -cmatch '\bRunContext\b[^.]{0,40}?\b(exposes|interface|methods?|provides|carries|has)\b') -or `
                          ($line26 -cmatch 'RunContext\.[A-Za-z_]')
        if ($isMethodsCtx26b) {
          # Extract method tokens AFTER the first RunContext occurrence to avoid catching
          # method calls owned by other classes that appear earlier in the line.
          $idxRC26 = $line26.IndexOf('RunContext')
          $afterRC26 = $line26.Substring($idxRC26)
          if ($afterRC26 -cmatch '\bposture\(') {
            Fail-Rule 'release_note_shipped_surface_truth' "$($rf26.FullName):$($i26+1) (26b) contains 'RunContext' co-mentioned with 'posture()'. Per ADR-0046 the actual RunContext interface has no posture() method; canonical methods are runId/tenantId/checkpointer/suspendForChild."
            $r26Fail = $true
          }
          $methodTokens26 = [regex]::Matches($afterRC26, '\b([A-Za-z_][A-Za-z0-9_]*)\(') | ForEach-Object { $_.Groups[1].Value }
          $canonical26b = @('runId','tenantId','checkpointer','suspendForChild')
          $neutral26b = @('exposes','lists','returns','threads','carries','provides','sourced','interface','method','methods','requires','reads','writes','sees','gets','fails')
          foreach ($mt26 in $methodTokens26) {
            if ($canonical26b -notcontains $mt26 -and $neutral26b -notcontains $mt26) {
              if ($mt26 -cmatch '^[a-z][A-Za-z0-9_]*$') {
                Fail-Rule 'release_note_shipped_surface_truth' "$($rf26.FullName):$($i26+1) (26b) lists method '$mt26()' alongside 'RunContext' in a methods-context. Per ADR-0046 canonical RunContext methods are {runId, tenantId, checkpointer, suspendForChild}; other method tokens flag an invented method."
                $r26Fail = $true
              }
            }
          }
        }
      }
      # --- 26c: OpenAPI snapshot test attribution ---
      if ($line26 -cmatch 'ApiCompatibilityTest' -and $line26 -cmatch 'snapshot|OpenAPI\s*(snapshot|spec|v1)|diverges|live\s*spec') {
        # Exempt clarifying lines that explicitly disclaim the misattribution.
        if ($line26 -notmatch 'ArchUnit\s*-?\s*only|not\s+the\s+OpenAPI|is\s+not\s+the\s+OpenAPI') {
          Fail-Rule 'release_note_shipped_surface_truth' "$($rf26.FullName):$($i26+1) (26c) attributes OpenAPI snapshot enforcement to ApiCompatibilityTest. Per ADR-0046 the snapshot diff lives in OpenApiContractIT (via OpenApiSnapshotComparator). ApiCompatibilityTest is ArchUnit-only."
          $r26Fail = $true
        }
      }
      # --- 26d: AppPostureGate scope guard ---
      if ($line26 -cmatch 'AppPostureGate' -and $line26 -cmatch 'HTTP\s*Edge') {
        Fail-Rule 'release_note_shipped_surface_truth' "$($rf26.FullName):$($i26+1) (26d) co-mentions 'AppPostureGate' with 'HTTP Edge'. Per ADR-0046 AppPostureGate lives in agent-runtime; it does not belong under HTTP Edge."
        $r26Fail = $true
      }
      if ($line26 -cmatch 'all\s+runtime\s+components.*posture.*constructor|posture.*constructor.*all\s+runtime\s+components') {
        Fail-Rule 'release_note_shipped_surface_truth' "$($rf26.FullName):$($i26+1) (26d) claims posture is a constructor argument for all runtime components. Per ADR-0046 only SyncOrchestrator, InMemoryRunRegistry, InMemoryCheckpointer call AppPostureGate; the claim is over-generalised."
        $r26Fail = $true
      }
    }
  }
}
if (-not $r26Fail) { Pass-Rule 'release_note_shipped_surface_truth' }

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if ($failCount -eq 0) {
  Write-Host 'GATE: PASS'
  exit 0
} else {
  Write-Host 'GATE: FAIL'
  exit 1
}
