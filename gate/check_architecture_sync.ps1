#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-fin architecture-sync gate (cycle-3 expanded).

.DESCRIPTION
  Catches drift classes from:
    docs/systematic-architecture-improvement-plan-2026-05-07.en.md sec-4-2
    docs/systematic-architecture-remediation-plan-2026-05-08.en.md sec-5 + sec-6 + sec-12
    docs/systematic-architecture-remediation-plan-2026-05-08-cycle-2.en.md sec-4 through sec-9
    docs/systematic-architecture-remediation-plan-2026-05-08-cycle-3.en.md sec-4 through sec-8

  Default mode: fails if working tree is dirty.
  -LocalOnly: passes with dirty tree but writes evidence_valid_for_delivery=false.

  Cycle-3 fixes:
    - Path normalization via Resolve-Path + ArrayList (no relative/absolute mix).
    - Closure-language enforcement is case-insensitive and uses regex.
    - rls_pool_lifecycle_matrix rule for docs/security-control-matrix.md.
    - docs/security-response-2026-05-08.md is excluded as historical.

.NOTES
  Architecture-sync gate, NOT Rule 8 operator-shape gate.
  Operator-shape smoke (gate/run_operator_shape_smoke.*) is W0 deliverable.
#>

[CmdletBinding()]
param(
  [switch]$LocalOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
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

function Rel([string]$abs) {
  if ([string]::IsNullOrEmpty($abs)) { return $abs }
  if ($abs.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    return ($abs.Substring($repoRoot.Length).TrimStart('\','/') -replace '\\','/')
  }
  return ($abs -replace '\\','/')
}

# ---- 0. Working tree state (cycle-2 sec-8) ----
$porcelain = ''
try { $porcelain = ((& git status --porcelain 2>$null) -join "`n") } catch { $porcelain = '' }
$treeClean = [string]::IsNullOrEmpty($porcelain)
if (-not $treeClean -and -not $LocalOnly) {
  Fail 'dirty_tree' 'working tree is dirty; pass -LocalOnly for non-delivery evidence' '' 0
}

# ---- 1. Build scan lists with path normalization (cycle-3 sec-4) ----
$AllScanFiles = New-Object System.Collections.ArrayList
$NonDocsArchFiles = New-Object System.Collections.ArrayList

function Add-ScanFile([System.Collections.ArrayList]$list, [string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return }
  try {
    $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
    [void]$list.Add($resolved.Path)
  } catch {
    # Silently skip non-existent paths (used by optional repo files).
  }
}

# L0
if (Test-Path 'ARCHITECTURE.md') {
  Add-ScanFile $AllScanFiles 'ARCHITECTURE.md'
  Add-ScanFile $NonDocsArchFiles 'ARCHITECTURE.md'
}

# L1/L2 ARCHITECTURE.md files under agent-platform/ and agent-runtime/
foreach ($root in @('agent-platform', 'agent-runtime')) {
  if (Test-Path $root) {
    Get-ChildItem -Path $root -Filter 'ARCHITECTURE.md' -Recurse -File -ErrorAction SilentlyContinue |
      ForEach-Object {
        Add-ScanFile $AllScanFiles $_.FullName
        Add-ScanFile $NonDocsArchFiles $_.FullName
      }
  }
}

# docs/**/*.md (excluding review docs, taxonomy, and historical security-response)
if (Test-Path 'docs') {
  Get-ChildItem -Path 'docs' -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $relLower = (Rel $_.FullName).ToLower()
    $skip = $false
    if ($relLower.Contains('systematic-architecture-improvement-plan')) { $skip = $true }
    if ($relLower.Contains('systematic-architecture-remediation-plan')) { $skip = $true }
    if ($relLower.Contains('closure-taxonomy.md')) { $skip = $true }
    if ($relLower.Contains('security-response-2026-05-08')) { $skip = $true }   # cycle-3: historical
    if (-not $skip) { Add-ScanFile $AllScanFiles $_.FullName }
  }
}

# ---- Self-test: scan list invariants (cycle-3 sec-4 exit criterion) ----
foreach ($f in $AllScanFiles) {
  if (-not [System.IO.Path]::IsPathRooted($f)) {
    Fail 'gate_self_test_failed' "scan list contains non-absolute path: $f" '' 0
  }
  if (-not (Test-Path -LiteralPath $f)) {
    Fail 'gate_self_test_failed' "scan list contains non-existent path: $(Rel $f)" '' 0
  }
}

# ---- 2. Forbidden closure shortcuts: substring patterns (existing) ----
$forbiddenSubstrings = @(
  'production-ready pending implementation',
  'operator-gated by intention',
  'verified by review only'
)
foreach ($f in $AllScanFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($phrase in $forbiddenSubstrings) {
      if ($lines[$i] -like "*$phrase*") {
        Fail 'forbidden_closure_shortcut' "matched '$phrase'" $rel ($i + 1)
      }
    }
  }
}

# ---- 2b. Forbidden closure shortcuts: case-insensitive regex (cycle-3 sec-7) ----
$closureRegexes = @(
  @{ Name = 'closes_pn_phrase';        Pattern = '(?i)\bcloses?\s+(security\s+review\s+)?(?:§)?P[0-9]+-[0-9]+\b' },
  @{ Name = 'pn_closure_phrase';       Pattern = '(?i)\bP[0-9]+-[0-9]+\s+closure\b' },
  @{ Name = 'closure_rests_on_phrase'; Pattern = '(?i)\bclosure\s+rests\s+on\b' },
  @{ Name = 'closed_by_design_phrase'; Pattern = '(?i)\bclosed\s+by\s+design\b' },
  @{ Name = 'fixed_in_docs_phrase';    Pattern = '(?i)\bfixed\s+in\s+docs\b' },
  @{ Name = 'accepted_therefore_closed_phrase'; Pattern = '(?i)\baccepted,\s*therefore\s*closed\b' }
)
foreach ($f in $AllScanFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($r in $closureRegexes) {
      if ($lines[$i] -match $r.Pattern) {
        Fail 'forbidden_closure_shortcut' "matched '$($r.Name)'" $rel ($i + 1)
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

# ---- 4. ActionGuard stage drift ----
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

# ---- 6. Contract posture purity ----
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

# ---- 7. Auth algorithm policy ----
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

# ---- 8. RLS pool lifecycle (L1/L2 architecture docs) ----
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

# ---- 8b. RLS pool lifecycle in security-control-matrix.md (cycle-3 sec-6) ----
$securityMatrix = 'docs/security-control-matrix.md'
if (Test-Path $securityMatrix) {
  $lines = Get-Content -LiteralPath $securityMatrix
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -clike '*connectionInitSql*') {
      Fail 'rls_pool_lifecycle_matrix' "security-control-matrix.md cites 'connectionInitSql' as a tenant reset control (cycle-2 server L2 corrected this; the matrix must use TenantBinder + transaction-scoped GUC + PooledConnectionLeakageIT)" $securityMatrix ($i + 1)
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

# ---- 11. Status enum sanity ----
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
  version                      = 'cycle-3-expanded'
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
