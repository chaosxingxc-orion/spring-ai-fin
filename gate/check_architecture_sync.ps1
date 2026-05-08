#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-fin architecture-sync gate (cycle-7 expanded).

.DESCRIPTION
  Cycle-7 changes:
    - Variable initialization moved to top of rule body (was crashing
      because cycle-6 readme_to_files used $gateReadme before the
      original gate_log_extension_drift assigned it).
    - Whole rule body wrapped so a runtime error emits structured
      gate_runtime_error JSON instead of crashing.
    - delivery_log_parity rule extended to match POSIX semantics
      (sha + semantic_pass + evidence_valid_for_delivery).
    - audit_trail_shape rule: enforces evidence-manifest/v2 two-SHA model
      via git rev-parse and git diff --name-only.
    - manifest_edge_consistency rule: validates manifest <-> delivery <->
      log <-> status <-> index edges.
    - ascii_only_governance rule: active governance files must be ASCII.
    - capability_legacy_bucket rule: forbids new findings using
      capability: operator_shape_gate.

.NOTES
  Architecture-sync gate, NOT Rule 8 operator-shape gate.
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

# ---- Shared variable initialization (cycle-7 A1: must precede any rule using these) ----
$gateReadme = 'gate/README.md'
$delReadme = 'docs/delivery/README.md'
$securityMatrix = 'docs/security-control-matrix.md'
$matrixPath = 'docs/governance/decision-sync-matrix.md'
$statusPath = 'docs/governance/architecture-status.yaml'
$manifestPath = 'docs/governance/evidence-manifest.yaml'
$indexPath = 'docs/governance/current-architecture-index.md'
$agL2 = 'agent-runtime/action-guard/ARCHITECTURE.md'
$agentPlatformL1 = 'agent-platform/ARCHITECTURE.md'
$l0 = 'ARCHITECTURE.md'

# ---- Wrap whole rule body so runtime errors emit structured JSON ----
$shaCandidate = ''
try { $shaCandidate = ((& git rev-parse --short HEAD 2>$null) -join '').Trim() } catch { $shaCandidate = 'no-git' }
if ([string]::IsNullOrEmpty($shaCandidate)) { $shaCandidate = 'no-git' }

$ruleBodySucceeded = $true
$runtimeErrorMessage = ''

try {

# 0. Working tree.
$porcelain = ''
try { $porcelain = ((& git status --porcelain 2>$null) -join "`n") } catch { $porcelain = '' }
$treeClean = [string]::IsNullOrEmpty($porcelain)
if (-not $treeClean -and -not $LocalOnly) {
  Fail 'dirty_tree' 'working tree is dirty; pass -LocalOnly for non-delivery evidence' '' 0
}

# 1. Build scan lists.
$AllScanFiles = New-Object System.Collections.ArrayList
$NonDocsArchFiles = New-Object System.Collections.ArrayList
$PlatformArchFiles = New-Object System.Collections.ArrayList

function Add-ScanFile([System.Collections.ArrayList]$list, [string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return }
  try {
    $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
    [void]$list.Add($resolved.Path)
  } catch {}
}

if (Test-Path $l0) {
  Add-ScanFile $AllScanFiles $l0
  Add-ScanFile $NonDocsArchFiles $l0
}

foreach ($root in @('agent-platform', 'agent-runtime')) {
  if (Test-Path $root) {
    Get-ChildItem -Path $root -Filter 'ARCHITECTURE.md' -Recurse -File -ErrorAction SilentlyContinue |
      ForEach-Object {
        Add-ScanFile $AllScanFiles $_.FullName
        Add-ScanFile $NonDocsArchFiles $_.FullName
      }
  }
}

if (Test-Path 'agent-platform') {
  Get-ChildItem -Path 'agent-platform' -Filter 'ARCHITECTURE.md' -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object { Add-ScanFile $PlatformArchFiles $_.FullName }
}

if (Test-Path 'docs') {
  Get-ChildItem -Path 'docs' -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $relLower = (Rel $_.FullName).ToLower()
    $skip = $false
    if ($relLower.Contains('systematic-architecture-improvement-plan')) { $skip = $true }
    if ($relLower.Contains('systematic-architecture-remediation-plan')) { $skip = $true }
    if ($relLower.Contains('closure-taxonomy.md')) { $skip = $true }
    if ($relLower.Contains('security-response-2026-05-08')) { $skip = $true }
    if ($relLower.Contains('architecture-v5.0')) { $skip = $true }
    if ($relLower.Contains('architecture-review-2026-05-07')) { $skip = $true }
    if ($relLower.Contains('deep-architecture-security-assessment')) { $skip = $true }
    if (-not $skip) { Add-ScanFile $AllScanFiles $_.FullName }
  }
}

foreach ($f in $AllScanFiles) {
  if (-not [System.IO.Path]::IsPathRooted($f)) {
    Fail 'gate_self_test_failed' "scan list contains non-absolute path: $f" '' 0
  }
  if (-not (Test-Path -LiteralPath $f)) {
    Fail 'gate_self_test_failed' "scan list contains non-existent path: $(Rel $f)" '' 0
  }
}

# 2. Forbidden closure shortcuts: substring patterns.
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

# 2b. Forbidden closure shortcuts: case-insensitive regex.
$closureRegexes = @(
  @{ Name = 'closes_pn_phrase';        Pattern = '(?i)\bcloses?\s+(security\s+review\s+)?(?:sec-)?P[0-9]+-[0-9]+\b' },
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

# 3. Saga overpromised consistency.
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

# 4. ActionGuard stage drift.
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

# 5. ActionGuard pre/post evidence stages.
if (Test-Path $agL2) {
  $content = Get-Content -Raw -LiteralPath $agL2
  if ($content -cnotmatch 'PreActionEvidenceWriter') {
    Fail 'actionguard_pre_post_evidence_missing' "action-guard L2 does not mention 'PreActionEvidenceWriter'" $agL2 0
  }
  if ($content -cnotmatch 'PostActionEvidenceWriter') {
    Fail 'actionguard_pre_post_evidence_missing' "action-guard L2 does not mention 'PostActionEvidenceWriter'" $agL2 0
  }
}

# 6. Contract posture purity.
$badPostureRegex = @(
  'contracts read .* `Environment\.getProperty',
  'contracts read posture from .Environment',
  'Posture in .Environment\.getProperty. for contracts',
  'contracts/.* package reads .APP_POSTURE',
  'contracts read .* via .Environment',
  'mirror via .Environment\.getProperty'
)
foreach ($f in $PlatformArchFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($pat in $badPostureRegex) {
      if ($lines[$i] -cmatch $pat) {
        Fail 'contract_posture_purity' "matched '$pat'" $rel ($i + 1)
      }
    }
  }
}

# 7. Auth algorithm policy.
foreach ($f in $PlatformArchFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -clike '*APP_JWT_SECRET*') {
      $context = $lines[$i]
      if ($i -gt 0) { $context += ' ' + $lines[$i - 1] }
      if ($i + 1 -lt $lines.Count) { $context += ' ' + $lines[$i + 1] }
      if ($context -cnotmatch '(?i)(BYOC|loopback|carve-out|allowlist|no longer the standard|HmacValidator|only when|optional)') {
        Fail 'auth_algorithm_policy' "APP_JWT_SECRET mentioned without BYOC/loopback/carve-out/allowlist/HmacValidator/optional qualifier" $rel ($i + 1)
      }
    }
  }
}

# 8. RLS pool lifecycle.
foreach ($f in $NonDocsArchFiles) {
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -clike '*connectionInitSql*') {
      $bad = $false
      if ($line -cmatch "connectionInitSql\s*=\s*'RESET\s+ROLE.*RESET\s+app\.tenant_id") { $bad = $true }
      if ($line -clike '*every checkout*' -and $line -cnotmatch '(?i)not\s+on\s+every\s+checkout') { $bad = $true }
      if ($line -cmatch '(?<!not.*)between\s+leases' -and $line -cnotmatch '(?i)not.*between\s+leases') { $bad = $true }
      if ($bad) {
        Fail 'rls_pool_lifecycle' "doc claims 'connectionInitSql' is a per-checkout reset hook" $rel ($i + 1)
      }
    }
  }
}

# 8b. RLS pool lifecycle in security-control-matrix.md.
if (Test-Path $securityMatrix) {
  $lines = Get-Content -LiteralPath $securityMatrix
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -clike '*connectionInitSql*') {
      Fail 'rls_pool_lifecycle_matrix' "security-control-matrix.md cites 'connectionInitSql' as a tenant reset control" $securityMatrix ($i + 1)
    }
  }
}

# 8c. RLS reset vocabulary.
$rlsVocabFiles = @($NonDocsArchFiles) + @($statusPath, $matrixPath, 'docs/trust-boundary-diagram.md', $securityMatrix)
$rlsVocabPhrases = @('HikariCP reset', 'HikariConnectionResetPolicy', 'reset on connection check-in', 'reset on check-in', 'connection check-in reset')
foreach ($f in $rlsVocabFiles) {
  if (-not (Test-Path $f)) { continue }
  $rel = Rel $f
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    foreach ($phrase in $rlsVocabPhrases) {
      if ($line -clike "*$phrase*") {
        if ($line -cnotmatch '(?i)(not\s|removed|deprecated|no longer|instead of|was wrong|cycle-[0-9])') {
          Fail 'rls_reset_vocabulary' "matched stale RLS reset wording '$phrase' without negation/deprecation marker" $rel ($i + 1)
        }
      }
    }
  }
}

# 8d. HS256 + prod conflict (cycle-6 C1 extension).
$hsProdScanFiles = @($securityMatrix, 'agent-runtime/auth/ARCHITECTURE.md')
foreach ($f in $hsProdScanFiles) {
  if (-not (Test-Path $f)) { continue }
  $lines = Get-Content -LiteralPath $f
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $hasHs256 = ($line -cmatch '(?i)(HS256|HMAC-SHA256|APP_JWT_SECRET)')
    $hasProd = ($line -cmatch '(?i)\bprod\b')
    $isRejected = ($line -cmatch '(?i)(rejected|not permitted|refused|reject HmacValidator|not a prod boot input|HmacValidator is active|only when|no HS256 path|HS256 only for|HS256 only on|only for DEV|only for BYOC|mandatory for|mandatory regardless|explicit BYOC|carve-out only|with carve-out|loopback only)')
    if ($hasHs256 -and $hasProd -and (-not $isRejected)) {
      Fail 'hs256_prod_conflict' "doc mentions HS256/APP_JWT_SECRET + prod without rejected/not-permitted qualifier" $f ($i + 1)
    }
  }
}

# 9. Gate path drift.
if (Test-Path $matrixPath) {
  $lines = Get-Content -LiteralPath $matrixPath
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -cmatch 'scripts/check_architecture_sync\.') {
      Fail 'gate_path_drift' "decision-sync-matrix.md references scripts/check_architecture_sync.* but the canonical path is gate/" $matrixPath ($i + 1)
    }
  }
}

# 10. Gate log extension drift.
if ((Test-Path $gateReadme) -and (Test-Path $delReadme)) {
  $gate = Get-Content -Raw -LiteralPath $gateReadme
  $del = Get-Content -Raw -LiteralPath $delReadme
  $gateExt = if ($gate -cmatch 'gate/log/<sha>\.(json|txt)') { $matches[1] } else { '' }
  $delExt  = if ($del  -cmatch 'gate/log/<sha>\.(json|txt)') { $matches[1] } else { '' }
  if ($gateExt -and $delExt -and ($gateExt -ne $delExt)) {
    Fail 'gate_log_extension_drift' "gate/README.md says .$gateExt but docs/delivery/README.md says .$delExt" 'gate/README.md;docs/delivery/README.md' 0
  }
}

# 11. Status enum sanity.
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

# 12. L2 referenced but missing.
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

# 13. L0 'Last refreshed' date.
if (Test-Path $l0) {
  $head = Get-Content -LiteralPath $l0 -TotalCount 5
  $headLine = $head | Where-Object { $_ -match 'Last refreshed' } | Select-Object -First 1
  if ($headLine -and $headLine -notmatch 'Last refreshed:\*\*\s*2026-05-08') {
    Fail 'l0_stale_refresh_date' "L0 'Last refreshed' should be 2026-05-08; current: $headLine" $l0 3
  }
}

# 14. Manifest freshness (cycle-6 A2; cycle-7 extended).
$reviewedContentSha = ''
$evidenceCommitSha = ''
$evidenceClassification = ''
$manifestDelivery = ''
if (Test-Path $manifestPath) {
  $manifestLines = Get-Content -LiteralPath $manifestPath
  foreach ($rawLine in $manifestLines) {
    $hashIdx = $rawLine.IndexOf('#')
    $line = if ($hashIdx -ge 0) { $rawLine.Substring(0, $hashIdx).TrimEnd() } else { $rawLine }
    if ($line -match '^reviewed_content_sha:\s*([A-Za-z0-9]+)') { $reviewedContentSha = $matches[1] }
    if ($line -match '^evidence_commit_sha:\s*([A-Za-z0-9]+)') { $evidenceCommitSha = $matches[1] }
    if ($line -match '^evidence_commit_classification:\s*([A-Za-z_]+)') { $evidenceClassification = $matches[1] }
    if ($line -match '^delivery_file:\s*(.+)$') { $manifestDelivery = $matches[1].Trim() }
    if ([string]::IsNullOrEmpty($reviewedContentSha) -and $line -match '^reviewed_sha:\s*([A-Za-z0-9]+)') {
      $reviewedContentSha = $matches[1]
    }
  }
  if ($reviewedContentSha -and $reviewedContentSha -ne 'TBD') {
    if ($manifestDelivery -and -not (Test-Path $manifestDelivery)) {
      Fail 'manifest_freshness' "manifest.delivery_file references '$manifestDelivery' which does not exist" $manifestPath 0
    }
    # Verify reviewed_content_sha is reachable from HEAD.
    $isAncestor = $false
    try {
      & git merge-base --is-ancestor $reviewedContentSha HEAD 2>$null
      if ($LASTEXITCODE -eq 0) { $isAncestor = $true }
    } catch { }
    if (-not $isAncestor -and ($shaCandidate -ne $reviewedContentSha)) {
      Fail 'manifest_freshness' "manifest.reviewed_content_sha=$reviewedContentSha is not reachable from HEAD" $manifestPath 0
    }
  }
}

# 14b. Audit-trail shape (cycle-7 B1).
# evidence_commit_sha is always HEAD by definition; structural constraints
# are parent equality and allowed-paths subset.
if ($reviewedContentSha -and ($shaCandidate -ne 'no-git')) {
  if ($shaCandidate -eq $reviewedContentSha) {
    # Direct: HEAD == reviewed content
  } else {
    $parentSha = ''
    try { $parentSha = ((& git rev-parse --short HEAD^ 2>$null) -join '').Trim() } catch { $parentSha = '' }
    if (-not $parentSha) {
      Fail 'audit_trail_shape' "HEAD ($shaCandidate) != reviewed_content_sha ($reviewedContentSha) and HEAD has no parent" $manifestPath 0
    } elseif ($parentSha -ne $reviewedContentSha) {
      Fail 'audit_trail_shape' "HEAD ($shaCandidate) parent is $parentSha but manifest.reviewed_content_sha is $reviewedContentSha; expected one-parent audit-trail shape" $manifestPath 0
    } else {
      $changedPaths = @()
      try { $changedPaths = (& git diff --name-only "$reviewedContentSha..HEAD" 2>$null) } catch { $changedPaths = @() }
      $allowedPatterns = @(
        '^docs/delivery/',
        '^docs/governance/architecture-status\.yaml$',
        '^docs/governance/current-architecture-index\.md$',
        '^docs/governance/evidence-manifest\.yaml$',
        '^gate/log/'
      )
      foreach ($cp in $changedPaths) {
        if ([string]::IsNullOrWhiteSpace($cp)) { continue }
        $allowed = $false
        foreach ($pat in $allowedPatterns) {
          if ($cp -match $pat) { $allowed = $true; break }
        }
        if (-not $allowed) {
          Fail 'audit_trail_shape' "audit-trail commit changed disallowed path: $cp" $manifestPath 0
        }
      }
    }
  }
}

# 14c. Manifest-edge consistency (cycle-7 B2 partial).
if ($reviewedContentSha -and (Test-Path $statusPath)) {
  $statusContent = Get-Content -Raw -LiteralPath $statusPath
  if ($statusContent -notmatch [regex]::Escape($reviewedContentSha)) {
    Fail 'manifest_edge_consistency' "architecture-status.yaml does not reference manifest.reviewed_content_sha=$reviewedContentSha" $statusPath 0
  }
}
if ($manifestDelivery -and (Test-Path $indexPath)) {
  $indexContent = Get-Content -Raw -LiteralPath $indexPath
  $deliveryBase = Split-Path -Leaf $manifestDelivery
  if ($indexContent -notmatch [regex]::Escape($deliveryBase)) {
    Fail 'manifest_edge_consistency' "current-architecture-index.md does not reference manifest.delivery_file=$deliveryBase" $indexPath 0
  }
}

# 15. README to files.
$smokePs1 = 'gate/run_operator_shape_smoke.ps1'
$smokeSh = 'gate/run_operator_shape_smoke.sh'
if (Test-Path $gateReadme) {
  if ((Test-Path $smokePs1) -or (Test-Path $smokeSh)) {
    $lines = Get-Content -LiteralPath $gateReadme
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]
      $bad = $false
      if (($line -cmatch '(?i)smoke gate') -and ($line -cmatch '(?i)(does not exist|not yet exist)')) { $bad = $true }
      if (($line -cmatch '(?i)run_operator_shape_smoke') -and ($line -cmatch '(?i)(does not exist|absent)')) { $bad = $true }
      if ($bad) {
        Fail 'readme_to_files' "gate/README.md says smoke gate does not exist while scripts are present in gate/" $gateReadme ($i + 1)
      }
    }
  }
}

# 16. Delivery-log parity (cycle-7 A2 extended to match POSIX semantics).
$deliveryFiles = Get-ChildItem -Path 'docs/delivery' -Filter '2026-05-08-*.md' -File -ErrorAction SilentlyContinue
foreach ($df in $deliveryFiles) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($df.Name)
  $sha = $base -replace '^2026-05-08-', ''
  if (-not $sha) { continue }
  $logFile = $null
  foreach ($candidate in @("gate/log/$sha-posix.json", "gate/log/$sha-windows.json", "gate/log/$sha.json")) {
    if (Test-Path $candidate) { $logFile = $candidate; break }
  }
  if (-not $logFile) { continue }
  $logContent = Get-Content -Raw -LiteralPath $logFile
  $logSha = if ($logContent -match '"sha":"([^"]+)"') { $matches[1] } else { '' }
  $logSemPass = if ($logContent -match '"semantic_pass":(true|false)') { $matches[1] } else { '' }
  $logEvValid = if ($logContent -match '"evidence_valid_for_delivery":(true|false)') { $matches[1] } else { '' }
  if ($logSha -and ($logSha -ne $sha)) {
    Fail 'delivery_log_parity' "log $logFile reports sha='$logSha' but the filename names sha='$sha'" $logFile 0
  }
  $deliveryRaw = Get-Content -Raw -LiteralPath $df.FullName
  if ($logSemPass -and ($deliveryRaw -match '\| `semantic_pass` \| ([^|]+)\|')) {
    $deliverySem = ($matches[1] -replace '[`*\s]','').Trim()
    if ($deliverySem -and ($deliverySem -ne $logSemPass)) {
      Fail 'delivery_log_parity' "delivery says semantic_pass=$deliverySem but log says $logSemPass" (Rel $df.FullName) 0
    }
  }
  if ($logEvValid -and ($deliveryRaw -match '\| `evidence_valid_for_delivery` \| ([^|]+)\|')) {
    $deliveryEv = ($matches[1] -replace '[`*\s]','').Trim()
    if ($deliveryEv -and ($deliveryEv -ne $logEvValid)) {
      Fail 'delivery_log_parity' "delivery says evidence_valid_for_delivery=$deliveryEv but log says $logEvValid" (Rel $df.FullName) 0
    }
  }
}

# 17. ASCII-only governance (cycle-7 D3).
$asciiFiles = @(
  $manifestPath,
  $indexPath,
  $statusPath,
  'docs/governance/closure-taxonomy.md',
  'docs/governance/decision-sync-matrix.md',
  'docs/governance/maturity-glossary.md',
  $delReadme,
  $gateReadme
)
foreach ($f in $asciiFiles) {
  if (-not (Test-Path $f)) { continue }
  $bytes = [System.IO.File]::ReadAllBytes($f)
  $lineNum = 1
  for ($i = 0; $i -lt $bytes.Count; $i++) {
    $b = $bytes[$i]
    if ($b -eq 10) { $lineNum++; continue }
    if ($b -eq 13) { continue }
    if ($b -eq 9) { continue }
    if ($b -lt 32 -or $b -gt 126) {
      Fail 'ascii_only_governance' ("non-ASCII byte 0x{0:X2} found" -f $b) (Rel $f) $lineNum
      break
    }
  }
}

# 18. Capability legacy-bucket (cycle-7 D2).
if (Test-Path $statusPath) {
  $statusLines = Get-Content -LiteralPath $statusPath
  $inFindingsSection = $false
  for ($i = 0; $i -lt $statusLines.Count; $i++) {
    $line = $statusLines[$i]
    if ($line -match '^findings:') { $inFindingsSection = $true }
    if (-not $inFindingsSection) { continue }
    if ($line -match '^\s+capability:\s*operator_shape_gate\s*$') {
      # Allow if the same finding has legacy_capability marker nearby (within 5 lines)
      $hasLegacy = $false
      for ($j = [Math]::Max(0, $i - 5); $j -le [Math]::Min($statusLines.Count - 1, $i + 5); $j++) {
        if ($statusLines[$j] -match '^\s+legacy_capability:\s*operator_shape_gate') { $hasLegacy = $true; break }
      }
      if (-not $hasLegacy) {
        Fail 'capability_legacy_bucket' "finding uses deprecated 'capability: operator_shape_gate' without legacy_capability marker; promote to architecture_sync_gate or operator_shape_smoke_gate" $statusPath ($i + 1)
      }
    }
  }
}

} catch {
  $ruleBodySucceeded = $false
  $runtimeErrorMessage = $_.Exception.Message
  Fail 'gate_runtime_error' "PowerShell rule body threw: $runtimeErrorMessage" '' 0
}

# Compute final state.
$semanticFailures = @($failures | Where-Object { $_.category -ne 'dirty_tree' })
$semanticPass = $semanticFailures.Count -eq 0
$evidenceValidForDelivery = $treeClean -and $semanticPass

if ($evidenceValidForDelivery) {
  $logDir = Join-Path $PSScriptRoot 'log'
} else {
  $logDir = Join-Path $PSScriptRoot 'log/local'
}
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$result = [pscustomobject]@{
  script                       = 'check_architecture_sync.ps1'
  version                      = 'cycle-7-expanded'
  platform                     = 'windows'
  sha                          = $shaCandidate
  generated                    = (Get-Date -Format 'o')
  scan_files_count             = $AllScanFiles.Count
  working_tree_clean           = $treeClean
  git_status_porcelain         = $porcelain
  local_only                   = [bool]$LocalOnly
  semantic_pass                = $semanticPass
  evidence_valid_for_delivery  = $evidenceValidForDelivery
  rule_body_succeeded          = $ruleBodySucceeded
  failures                     = $failures
}
$logPath = Join-Path $logDir "$shaCandidate-windows.json"
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logPath -Encoding UTF8

if ($failures.Count -gt 0) {
  Write-Host "FAIL: $($failures.Count) drift(s) found. See $logPath" -ForegroundColor Red
  $failures | Format-List | Out-Host
  exit 1
}
$evDelMsg = if ($evidenceValidForDelivery) { 'evidence_valid_for_delivery=true' } else { 'evidence_valid_for_delivery=false (local-only or dirty); log under gate/log/local/' }
Write-Host "PASS: architecture corpus is internally consistent. $evDelMsg. Log: $logPath" -ForegroundColor Green
exit 0
