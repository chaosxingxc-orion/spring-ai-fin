#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-fin architecture-sync gate (cycle-2 expanded).

.DESCRIPTION
  Catches drift classes from:
    docs/systematic-architecture-improvement-plan-2026-05-07.en.md sec-4-2
    docs/systematic-architecture-remediation-plan-2026-05-08.en.md sec-5 + sec-6 + sec-12
    docs/systematic-architecture-remediation-plan-2026-05-08-cycle-2.en.md sec-4 through sec-9

  Default mode: fails if working tree is dirty.
  -LocalOnly: passes with dirty tree but writes evidence_valid_for_delivery=false.

  Scan surfaces:
    ARCHITECTURE.md
    agent-platform/**/ARCHITECTURE.md
    agent-runtime/**/ARCHITECTURE.md
    docs/**/*.md (excluding review docs and closure-taxonomy.md)
    docs/governance/architecture-status.yaml
    docs/governance/decision-sync-matrix.md
    gate/README.md
    docs/delivery/README.md

.NOTES
  Architecture-sync gate, NOT Rule 8 operator-shape gate.
  Operator-shape smoke (gate/run_operator_shape_smoke.*) is W0 deliverable.
#>

[CmdletBinding()]
param(
  [switch]$LocalOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $repoRoot

$failures = New-Object System.Collections.ArrayList
function Fail([string]$category, [string]$message, [string]$path, [int]$line = 0) {
  $entry = [pscustomobject]@{
    category = $category
    message  = $message
    path     = $path
    line     = $line
  }
  [void]$failures.Add($entry)
}

# ---- 0. Working tree state (cycle-2 sec-8) ----
$porcelain = ''
try { $porcelain = ((& git status --porcelain 2>$null) -join "`n") } catch { $porcelain = '' }
$treeClean = [string]::IsNullOrEmpty($porcelain)
if (-not $treeClean -and -not $LocalOnly) {
  Fail 'dirty_tree' 'working tree is dirty; pass -LocalOnly for non-delivery evidence' '' 0
}

# ---- 1. Build scan lists ----
$L0 = if (Test-Path 'ARCHITECTURE.md') { @('ARCHITECTURE.md') } else { @() }

$L1L2 = @()
foreach ($root in @('agent-platform', 'agent-runtime')) {
  if (Test-Path $root) {
    $found = Get-ChildItem -Path $root -Filter 'ARCHITECTURE.md' -Recurse -File | Select-Object -ExpandProperty FullName
    if ($found) { $L1L2 += $found }
  }
}

$DocsAllowed = @()
if (Test-Path 'docs') {
  $DocsAllowed = Get-ChildItem -Path 'docs' -Filter '*.md' -Recurse -File | Where-Object {
    $rel = (($_.FullName.Substring($repoRoot.Path.Length + 1)) -replace '\\','/').ToLower()
    -not (
      $rel.Contains('systematic-architecture-improvement-plan') -or
      $rel.Contains('systematic-architecture-remediation-plan') -or
      $rel.Contains('closure-taxonomy.md')
    )
  } | Select-Object -ExpandProperty FullName
}

$AllScanFiles = @($L0 + $L1L2 + $DocsAllowed)
$NonDocsArchFiles = @($L0 + $L1L2)

function Rel([string]$abs) {
  if ([string]::IsNullOrEmpty($abs)) { return $abs }
  return (($abs.Substring($repoRoot.Path.Length + 1)) -replace '\\','/')
}

# ---- 2. Forbidden closure shortcuts (existing; expanded scope) ----
$forbidden = @(
  'closes security review P0-',
  'closes security review P1-',
  'closed by design',
  'fixed in docs',
  'production-ready pending implementation',
  'accepted, therefore closed',
  'operator-gated by intention',
  'verified by review only'
)
foreach ($f in $AllScanFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($phrase in $forbidden) {
      if ($lines[$i] -clike "*$phrase*") {
        Fail 'forbidden_closure_shortcut' "matched '$phrase'" $rel ($i + 1)
      }
    }
  }
}

# ---- 3. Saga overpromised consistency ----
$sagaForbidden = @('strong within saga', 'cross-entity strong consistency', 'all-or-nothing across step failure points')
foreach ($f in $NonDocsArchFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($phrase in $sagaForbidden) {
      if ($lines[$i] -clike "*$phrase*") {
        Fail 'saga_overpromised_consistency' "matched '$phrase'" $rel ($i + 1)
      }
    }
  }
}

# ---- 4. ActionGuard stage drift (cycle-2 sec-4) ----
$tenStagePatterns = @('10-stage', '10 stages', 'ten-stage', 'ten stages')
foreach ($f in $AllScanFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($pat in $tenStagePatterns) {
      if ($lines[$i] -clike "*$pat*") {
        $near = $false
        if ($lines[$i] -clike '*ActionGuard*') { $near = $true }
        elseif ($i -gt 0 -and $lines[$i - 1] -clike '*ActionGuard*') { $near = $true }
        elseif ($i + 1 -lt $lines.Count -and $lines[$i + 1] -clike '*ActionGuard*') { $near = $true }
        if ($near) {
          Fail 'actionguard_stage_drift' "matched '$pat' near 'ActionGuard'" $rel ($i + 1)
        }
      }
    }
  }
}

# ---- 5. ActionGuard pre/post evidence stages required in L2 ----
$agL2 = 'agent-runtime/action-guard/ARCHITECTURE.md'
if (Test-Path $agL2) {
  $content = Get-Content -Raw -LiteralPath $agL2
  if ($content -cnotmatch 'PreActionEvidenceWriter') {
    Fail 'actionguard_pre_post_evidence_missing' "action-guard L2 does not mention 'PreActionEvidenceWriter'" $agL2 0
  }
  if ($content -cnotmatch 'PostActionEvidenceWriter') {
    Fail 'actionguard_pre_post_evidence_missing' "action-guard L2 does not mention 'PostActionEvidenceWriter'" $agL2 0
  }
}

# ---- 6. Contract posture purity (cycle-2 sec-5) ----
$agentPlatformL1 = 'agent-platform/ARCHITECTURE.md'
if (Test-Path $agentPlatformL1) {
  $lines = Get-Content -LiteralPath $agentPlatformL1
  $badPatterns = @(
    'contracts read .* `Environment\.getProperty',
    'contracts read posture from .Environment',
    'Posture in .Environment\.getProperty. for contracts',
    'contracts/.* package reads .APP_POSTURE',
    'contracts read .* via .Environment'
  )
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($pat in $badPatterns) {
      if ($lines[$i] -cmatch $pat) {
        Fail 'contract_posture_purity' "matched '$pat'" $agentPlatformL1 ($i + 1)
      }
    }
  }
}

# ---- 7. Auth algorithm policy (cycle-2 sec-5) ----
if (Test-Path $agentPlatformL1) {
  $lines = Get-Content -LiteralPath $agentPlatformL1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -clike '*APP_JWT_SECRET*') {
      $context = $lines[$i]
      if ($i -gt 0) { $context += ' ' + $lines[$i - 1] }
      if ($i + 1 -lt $lines.Count) { $context += ' ' + $lines[$i + 1] }
      if ($context -cnotmatch '(?i)(BYOC|loopback|carve-out|allowlist|no longer the standard)') {
        Fail 'auth_algorithm_policy' "APP_JWT_SECRET mentioned without BYOC/loopback/carve-out/allowlist qualifier" $agentPlatformL1 ($i + 1)
      }
    }
  }
}

# ---- 8. RLS pool lifecycle (cycle-2 sec-6) ----
foreach ($f in $NonDocsArchFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -clike '*connectionInitSql*') {
      $bad = $false
      if ($line -cmatch "connectionInitSql\s*=\s*'RESET\s+ROLE.*RESET\s+app\.tenant_id") { $bad = $true }
      if ($line -clike '*every checkout*' -and $line -cnotmatch '(?i)not\s+on\s+every\s+checkout') { $bad = $true }
      if ($line -cmatch '(?<!not.*)between\s+leases' -and $line -clike '*connectionInitSql*' -and $line -cnotmatch '(?i)not.*between\s+leases') { $bad = $true }
      if ($bad) {
        Fail 'rls_pool_lifecycle' "doc claims 'connectionInitSql' is a per-checkout reset hook (HikariCP runs it only at connection creation)" $rel ($i + 1)
      }
    }
  }
}

# ---- 9. Gate path drift ----
$matrixPath = 'docs/governance/decision-sync-matrix.md'
if (Test-Path $matrixPath) {
  $lines = Get-Content -LiteralPath $matrixPath
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -cmatch 'scripts/check_architecture_sync\.') {
      Fail 'gate_path_drift' "decision-sync-matrix.md references scripts/check_architecture_sync.* but the canonical path is gate/" $matrixPath ($i + 1)
    }
  }
}

# ---- 10. Gate log extension drift ----
$gateReadme = 'gate/README.md'
$delReadme = 'docs/delivery/README.md'
if ((Test-Path $gateReadme) -and (Test-Path $delReadme)) {
  $gate = Get-Content -Raw -LiteralPath $gateReadme
  $del = Get-Content -Raw -LiteralPath $delReadme
  $gateExt = if ($gate -cmatch 'gate/log/<sha>\.(json|txt)') { $matches[1] } else { '' }
  $delExt  = if ($del  -cmatch 'gate/log/<sha>\.(json|txt)') { $matches[1] } else { '' }
  if ($gateExt -and $delExt -and ($gateExt -ne $delExt)) {
    Fail 'gate_log_extension_drift' "gate/README.md says .$gateExt but docs/delivery/README.md says .$delExt" 'gate/README.md;docs/delivery/README.md' 0
  }
}

# ---- 11. status enum sanity ----
$statusPath = 'docs/governance/architecture-status.yaml'
if (Test-Path $statusPath) {
  $allowed = @('proposed','design_accepted','implemented_unverified','test_verified','operator_gated','released')
  $lines = Get-Content -LiteralPath $statusPath
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match '^\s*status:\s*([A-Za-z_]+)\s*$') {
      $val = $matches[1]
      if (-not ($allowed -contains $val)) {
        Fail 'status_enum_invalid' "status '$val' is not in $($allowed -join ', ')" $statusPath ($i + 1)
      }
    }
  }
}

# ---- 12. L2 referenced but missing ----
if (Test-Path $matrixPath) {
  $matrix = Get-Content -Raw -LiteralPath $matrixPath
  $referenced = [regex]::Matches($matrix, '`(agent-[a-z0-9_/-]+/ARCHITECTURE\.md)`') |
    ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  foreach ($r in $referenced) {
    if (-not (Test-Path $r)) {
      Fail 'l2_referenced_but_missing' "decision-sync-matrix.md references $r but the file does not exist" $matrixPath 0
    }
  }
}

# ---- 13. L0 'Last refreshed' date ----
$l0 = 'ARCHITECTURE.md'
if (Test-Path $l0) {
  $head = Get-Content -LiteralPath $l0 -TotalCount 5
  $headLine = $head | Where-Object { $_ -match 'Last refreshed' } | Select-Object -First 1
  if ($headLine -and $headLine -notmatch 'Last refreshed:\*\*\s*2026-05-08') {
    Fail 'l0_stale_refresh_date' "L0 'Last refreshed' should be 2026-05-08; current: $headLine" $l0 3
  }
}

# ---- Emit structured log ----
$shaCandidate = ''
try { $shaCandidate = ((& git rev-parse --short HEAD 2>$null) -join '').Trim() } catch { $shaCandidate = 'no-git' }
if ([string]::IsNullOrEmpty($shaCandidate)) { $shaCandidate = 'no-git' }
$logDir = Join-Path $PSScriptRoot 'log'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }

$semanticFailures = @($failures | Where-Object { $_.category -ne 'dirty_tree' })
$semanticPass = $semanticFailures.Count -eq 0
$evidenceValidForDelivery = $treeClean -and $semanticPass

$result = [pscustomobject]@{
  script                       = 'check_architecture_sync.ps1'
  version                      = 'cycle-2-expanded'
  sha                          = $shaCandidate
  generated                    = (Get-Date -Format 'o')
  scan_files_count             = $AllScanFiles.Count
  working_tree_clean           = $treeClean
  git_status_porcelain         = $porcelain
  local_only                   = [bool]$LocalOnly
  semantic_pass                = $semanticPass
  evidence_valid_for_delivery  = $evidenceValidForDelivery
  failures                     = $failures
}
$logPath = Join-Path $logDir "$shaCandidate.json"
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logPath -Encoding UTF8

if ($failures.Count -gt 0) {
  Write-Host "FAIL: $($failures.Count) drift(s) found. See $logPath" -ForegroundColor Red
  $failures | Format-List | Out-Host
  exit 1
}
$evDelMsg = if ($evidenceValidForDelivery) { 'evidence_valid_for_delivery=true' } else { 'evidence_valid_for_delivery=false (local-only or dirty)' }
Write-Host "PASS: architecture corpus is internally consistent. $evDelMsg. Log: $logPath" -ForegroundColor Green
exit 0
