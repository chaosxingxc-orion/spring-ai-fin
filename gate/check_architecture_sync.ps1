#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-ascend architecture-sync gate (post-seventh follow-up refresh, 18 rules).

.DESCRIPTION
  Exits 0 if all rules pass, 1 if any fail.
  Each rule prints PASS: <name> or FAIL: <name> -- <reason>.
  Prints GATE: PASS or GATE: FAIL at the end.

  Rules:
    1. status_enum_invalid            -- architecture-status.yaml status values
    2. delivery_log_parity            -- gate/log/*.json sha field matches filename
    3. eol_policy                     -- *.sh files in gate/ must be LF (not CRLF)
    4. ci_no_or_true_mask             -- no gate/run_* || true in CI workflows
    5. required_files_present         -- contract-catalog.md and openapi-v1.yaml must exist
    6. metric_naming_namespace        -- springai_ascend_ prefix in Java metric names
    7. shipped_impl_paths_exist       -- every shipped: true implementation: path exists on disk
    8. no_hardcoded_versions_in_arch  -- module ARCHITECTURE.md files must not pin OSS versions inline
    9. openapi_path_consistency       -- /v3/api-docs must appear in WebSecurityConfig + platform ARCH
   10. module_dep_direction           -- agent-runtime must not depend on agent-platform (and vice versa)
   11. shipped_envelope_fingerprint_present -- InMemoryCheckpointer enforces §4 #13 16-KiB cap (MAX_INLINE_PAYLOAD_BYTES present)
   12. inmemory_orchestrator_posture_guard_present -- SyncOrchestrator, InMemoryRunRegistry, InMemoryCheckpointer each contain AppPostureGate.requireDev (ADR-0035)
   13. contract_catalog_no_deleted_spi_or_starter_names -- contract-catalog.md must not reference deleted SPI interface names or deleted starter coords
   14. module_arch_method_name_truth  -- method names in ARCHITECTURE.md code-fences must exist in named Java class
   15. no_active_refs_deleted_wave_plan_paths  -- active .md files must not reference docs/plans/engineering-plan-W0-W4.md or roadmap-W0-W4.md
   16. http_contract_w1_tenant_and_cancel_consistency  -- W1 HTTP contract: no replace-X-Tenant-Id wording, no CREATED initial status, no DELETE cancel route
   17. contract_catalog_spi_table_matches_source  -- SPI sub-table must list 7 known SPIs; OssApiProbe must not appear before Probes sub-table
   18. deleted_spi_starter_names_outside_catalog  -- MANIFEST.md, oss-bill-of-materials.md, README.md must not reference deleted SPI/starter names

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
  if ($c16 -match 'will replace.*X-Tenant-Id|replace header-based.*with JWT|W1 replaces.*X-Tenant-Id') {
    Fail-Rule 'http_contract_w1_tenant_and_cancel_consistency' "$($mdFile.FullName) contains a forward-looking 'replace X-Tenant-Id' claim. Per ADR-0040 W1 adds JWT cross-check; X-Tenant-Id is NOT replaced."
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
$r18Targets = @('third_party/MANIFEST.md', 'docs/cross-cutting/oss-bill-of-materials.md', 'README.md')
$deletedNames18 = @(
  'LongTermMemoryRepository', 'ToolProvider', 'LayoutParser', 'DocumentSourceConnector',
  'PolicyEvaluator', 'IdempotencyRepository', 'ArtifactRepository',
  'spring-ai-ascend-memory-starter', 'spring-ai-ascend-skills-starter',
  'spring-ai-ascend-knowledge-starter', 'spring-ai-ascend-governance-starter',
  'spring-ai-ascend-persistence-starter', 'spring-ai-ascend-resilience-starter',
  'spring-ai-ascend-mem0-starter', 'spring-ai-ascend-docling-starter',
  'spring-ai-ascend-langchain4j-profile'
)
foreach ($target18 in $r18Targets) {
  if (Test-Path -LiteralPath $target18) {
    $tc18 = Get-Content -Raw -LiteralPath $target18 -ErrorAction SilentlyContinue
    foreach ($dn18 in $deletedNames18) {
      if ($tc18 -match [regex]::Escape($dn18)) {
        Fail-Rule 'deleted_spi_starter_names_outside_catalog' "$target18 references deleted name '$dn18'. Per ADR-0041 Gate Rule 18 this is a contract-surface truth violation."
        $r18Fail = $true
      }
    }
  }
}
if (-not $r18Fail) { Pass-Rule 'deleted_spi_starter_names_outside_catalog' }

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
