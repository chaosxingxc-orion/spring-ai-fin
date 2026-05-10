#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-fin architecture-sync gate (cycle-8 evidence graph v3).

.DESCRIPTION
  Cycle-8 changes (this version: "cycle-8-evidence-graph-v3"):
    - eol_policy rule (A1): tracked *.sh must be LF in working tree.
    - delivery_log_exact_binding rule (B1): authoritative delivery files
      MUST name a log path that exists and whose sha equals
      reviewed_content_sha or evidence_commit_sha.
    - delivery_log_parity (B2): no skip on missing log for current
      authoritative delivery; legacy exemptions are explicit in manifest.
    - manifest_no_tbd / manifest_no_null_log_slots rules (B3).
    - ascii_only_active_corpus rule (D1): replaces ascii_only_governance;
      scan list derived from docs/governance/active-corpus.yaml.
    - rule_8_state_consistency rule (C2).

  Cycle-7 baseline (unchanged):
    - audit_trail_shape rule (B1): two-SHA evidence model.
    - manifest_edge_consistency rule (B2).
    - capability_legacy_bucket rule (D2).
    - Variable initialization above all rules; rule body try-wrapped.

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
$securityMatrix = 'docs/cross-cutting/security-control-matrix.md'
$matrixPath = 'docs/governance/decision-sync-matrix.md'
$statusPath = 'docs/governance/architecture-status.yaml'
$manifestPath = 'docs/governance/evidence-manifest.yaml'
$indexPath = 'docs/governance/current-architecture-index.md'
$agL2 = 'agent-runtime/action/ARCHITECTURE.md'
$agL2Legacy = 'agent-runtime/action-guard/ARCHITECTURE.md'
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

# 5. ActionGuard 5-stage invariants (cycle-9 sec-C2).
# Rule migrated from action-guard/ to action/ per the cycle-9 truth-cut.
if (Test-Path $agL2) {
  $content = Get-Content -Raw -LiteralPath $agL2
  foreach ($stage in @('Authenticate','Authorize','Bound','Execute','Witness')) {
    if ($content -cnotmatch [regex]::Escape($stage)) {
      Fail 'actionguard_5stage_invariants' "action L2 does not mention 5-stage name '$stage'" $agL2 0
    }
  }
  if ($content -cnotmatch '(?i)(audit row|audit log|append-only|INSERT-only)') {
    Fail 'actionguard_5stage_invariants' "action L2 does not mention audit-row invariant" $agL2 0
  }
  if ($content -cnotmatch '(?i)(outbox event|outbox row|outbox_event)') {
    Fail 'actionguard_5stage_invariants' "action L2 does not mention outbox-event invariant" $agL2 0
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

# 8b. RLS pool lifecycle in docs/cross-cutting/security-control-matrix.md.
if (Test-Path $securityMatrix) {
  $lines = Get-Content -LiteralPath $securityMatrix
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -clike '*connectionInitSql*') {
      Fail 'rls_pool_lifecycle_matrix' "docs/cross-cutting/security-control-matrix.md cites 'connectionInitSql' as a tenant reset control" $securityMatrix ($i + 1)
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

# 16. Delivery-log parity (cycle-7 A2; cycle-8 B2 no-skip-on-missing for
# current authoritative delivery; legacy_exemptions explicit in manifest).
$deliveryFiles = Get-ChildItem -Path 'docs/delivery' -Filter '????-??-??-*.md' -File -ErrorAction SilentlyContinue
foreach ($df in $deliveryFiles) {
  $base = [System.IO.Path]::GetFileNameWithoutExtension($df.Name)
  $sha = $base -replace '^\d{4}-\d{2}-\d{2}-', ''
  if (-not $sha) { continue }
  $logFile = $null
  foreach ($candidate in @("gate/log/$sha-posix.json", "gate/log/$sha-windows.json", "gate/log/$sha.json")) {
    if (Test-Path $candidate) { $logFile = $candidate; break }
  }
  if (-not $logFile) {
    # Cycle-8 B2: do not silently skip.
    $legacyExempt = $false
    if (Test-Path $manifestPath) {
      $mfText = Get-Content -Raw -LiteralPath $manifestPath
      $relDf = (Rel $df.FullName)
      if ($mfText -match [regex]::Escape($relDf)) {
        $idx = $mfText.IndexOf($relDf)
        $window = $mfText.Substring($idx, [Math]::Min(400, $mfText.Length - $idx))
        if ($window -match 'pre_platform_suffix_legacy') { $legacyExempt = $true }
      }
    }
    $isCurrent = $false
    if ($manifestDelivery) {
      $relDfNorm = (Rel $df.FullName) -replace '\\','/'
      $manDelNorm = $manifestDelivery -replace '\\','/'
      if ($relDfNorm -eq $manDelNorm) { $isCurrent = $true }
    }
    if ($isCurrent -and -not $legacyExempt) {
      Fail 'delivery_log_parity' "current authoritative delivery $($df.Name) has no matching gate/log/$sha-*.json" (Rel $df.FullName) 0
    }
    continue
  }
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

# 17. ASCII-only active corpus (cycle-8 D1; cycle-9 split-aware).
# Scan list derived from docs/governance/active-corpus.yaml#active_documents
# ONLY -- never from transitional_rationale or historical_documents.
$activeCorpusPath = 'docs/governance/active-corpus.yaml'
$asciiFiles = @()
$activePaths = @()
if (Test-Path $activeCorpusPath) {
  $inActive = $false
  foreach ($yLine in (Get-Content -LiteralPath $activeCorpusPath)) {
    if ($yLine -match '^active_documents:') { $inActive = $true; continue }
    if ($yLine -match '^transitional_rationale:') { $inActive = $false; continue }
    if ($yLine -match '^historical_documents:') { $inActive = $false; continue }
    if (-not $inActive) { continue }
    if ($yLine -match '^\s+-\s+path:\s+(\S+)\s*$') {
      $asciiFiles += $matches[1]
      $activePaths += $matches[1]
    }
  }
}
if ($asciiFiles.Count -eq 0) {
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
  Fail 'active_corpus_registry_missing' "active-corpus.yaml not parseable; falling back to cycle-7 minimal scan list" $activeCorpusPath 0
}
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
      Fail 'ascii_only_active_corpus' ("non-ASCII byte 0x{0:X2} found" -f $b) (Rel $f) $lineNum
      break
    }
  }
}

# 19. EOL policy (cycle-8 A1): tracked *.sh files must be LF in working tree.
$shellFiles = @()
try { $shellFiles = & git ls-files '*.sh' 2>$null } catch { $shellFiles = @() }
foreach ($shf in $shellFiles) {
  if ([string]::IsNullOrWhiteSpace($shf)) { continue }
  if (-not (Test-Path -LiteralPath $shf)) { continue }
  $bytes = [System.IO.File]::ReadAllBytes($shf)
  $hasCr = $false
  foreach ($b in $bytes) {
    if ($b -eq 13) { $hasCr = $true; break }
  }
  if ($hasCr) {
    Fail 'eol_policy' "shell script contains CRLF; must be LF (see .gitattributes)" $shf 0
  }
}
if (-not (Test-Path '.gitattributes')) {
  Fail 'eol_policy' ".gitattributes does not exist; LF policy is unenforced" '.gitattributes' 0
}

# 20. Manifest no TBD / no null log slots (cycle-8 B3).
if (Test-Path $manifestPath) {
  $manifestRaw = Get-Content -LiteralPath $manifestPath
  for ($i = 0; $i -lt $manifestRaw.Count; $i++) {
    $line = $manifestRaw[$i]
    $hashIdx = $line.IndexOf('#')
    $stripped = if ($hashIdx -ge 0) { $line.Substring(0, $hashIdx).TrimEnd() } else { $line }
    if ($stripped -match ':\s*TBD\s*$') {
      Fail 'manifest_no_tbd' "manifest has 'TBD' value; replace with explicit value or state" $manifestPath ($i + 1)
    }
    if ($stripped -match '^\s+state:\s*null\s*$') {
      Fail 'manifest_no_null_log_slots' "manifest has 'state: null'; use the closed state enum" $manifestPath ($i + 1)
    }
  }
}

# 21. Delivery-log exact binding (cycle-8 B1).
if ($manifestDelivery -and (Test-Path $manifestDelivery) -and $reviewedContentSha) {
  $deliveryBase = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Leaf $manifestDelivery))
  $deliverySha = $deliveryBase -replace '^\d{4}-\d{2}-\d{2}-', ''
  $foundLog = $null
  foreach ($candidate in @("gate/log/$deliverySha-posix.json", "gate/log/$deliverySha-windows.json", "gate/log/$deliverySha.json")) {
    if (Test-Path $candidate) { $foundLog = $candidate; break }
  }
  $legacyExempt = $false
  if (Test-Path $manifestPath) {
    $mfText = Get-Content -Raw -LiteralPath $manifestPath
    if ($mfText -match [regex]::Escape($manifestDelivery)) {
      $idx = $mfText.IndexOf($manifestDelivery)
      $window = $mfText.Substring($idx, [Math]::Min(400, $mfText.Length - $idx))
      if ($window -match 'pre_platform_suffix_legacy') { $legacyExempt = $true }
    }
  }
  if (-not $foundLog -and -not $legacyExempt) {
    Fail 'delivery_log_exact_binding' "manifest.delivery_file=$manifestDelivery has no matching gate/log/$deliverySha-*.json (and no legacy exemption)" $manifestPath 0
  }
  if ($foundLog) {
    $logRaw = Get-Content -Raw -LiteralPath $foundLog
    $logSha = if ($logRaw -match '"sha":"([^"]+)"') { $matches[1] } else { '' }
    if ($logSha -and $logSha -ne $reviewedContentSha -and $logSha -ne $shaCandidate) {
      Fail 'delivery_log_exact_binding' "log $foundLog reports sha='$logSha' which is neither reviewed_content_sha=$reviewedContentSha nor HEAD=$shaCandidate" $foundLog 0
    }
  }
}

# 23. Active corpus exclusivity (cycle-9 A1, B1): no active_documents
# entry may carry a v7_disposition / supersedes_to / sunset_by marker.
if (Test-Path $activeCorpusPath) {
  $inActive = $false
  $curPath = ''
  $lineNum = 0
  foreach ($yLine in (Get-Content -LiteralPath $activeCorpusPath)) {
    $lineNum++
    if ($yLine -match '^active_documents:') { $inActive = $true; $curPath = ''; continue }
    if ($yLine -match '^transitional_rationale:') { $inActive = $false; $curPath = ''; continue }
    if ($yLine -match '^historical_documents:') { $inActive = $false; $curPath = ''; continue }
    if (-not $inActive) { continue }
    if ($yLine -match '^\s+-\s+path:\s+(\S+)\s*$') { $curPath = $matches[1]; continue }
    if ($curPath) {
      foreach ($marker in @('v7_disposition','supersedes_to','sunset_by')) {
        if ($yLine -match "^\s+${marker}:") {
          Fail 'active_corpus_no_disposition_in_active' "active_documents entry $curPath has forbidden field '$marker' (cycle-9 A1)" $activeCorpusPath $lineNum
        }
      }
    }
  }
}

# 24. Index active subset (cycle-9 B2): primary hierarchy in
# current-architecture-index.md must be a subset of active_documents.
if ((Test-Path $indexPath) -and ($activePaths.Count -gt 0)) {
  $activeBasenames = $activePaths | ForEach-Object { Split-Path -Leaf $_ }
  $indexLines = Get-Content -LiteralPath $indexPath
  $inActiveSection = $false
  for ($i = 0; $i -lt $indexLines.Count; $i++) {
    $line = $indexLines[$i]
    if ($line -match '^## Active hierarchy') { $inActiveSection = $true; continue }
    # Stop at the next top-level "## " section (any one) -- only the
    # Active hierarchy section is treated as the architecture hierarchy.
    if ($inActiveSection -and $line -match '^## ') { $inActiveSection = $false; continue }
    if (-not $inActiveSection) { continue }
    $linkMatches = [regex]::Matches($line, '\(([^\)]+\.md)\)')
    foreach ($lm in $linkMatches) {
      $link = $lm.Groups[1].Value
      $base = Split-Path -Leaf $link
      $found = $activeBasenames -contains $base
      if (-not $found) {
        switch -Regex ($base) {
          '^ARCHITECTURE\.md$' { $found = $true }
          '\.(yaml|json)$' { $found = $true }
        }
      }
      if (-not $found) {
        Fail 'index_active_subset' "current-architecture-index.md active hierarchy references non-active path: $link" $indexPath ($i + 1)
      }
    }
  }
}

# 22. Rule 8 state consistency (cycle-8 C2).
$rule8State = ''
if (Test-Path $manifestPath) {
  $manifestText = Get-Content -Raw -LiteralPath $manifestPath
  if ($manifestText -match '(?ms)^rule_8:\s*\r?\n\s+state:\s*([A-Za-z_]+)') {
    $rule8State = $matches[1]
  }
}
if ($rule8State -eq 'fail_closed_artifact_missing' -and (Test-Path $statusPath)) {
  $statusLines = Get-Content -LiteralPath $statusPath
  for ($i = 0; $i -lt $statusLines.Count; $i++) {
    $line = $statusLines[$i]
    if ($line -match '^\s+maturity:\s*L3\b') {
      Fail 'rule_8_state_consistency' "capability declares maturity: L3 while manifest.rule_8.state=fail_closed_artifact_missing" $statusPath ($i + 1)
    }
    if ($line -match '^\s+maturity:\s*L4\b') {
      Fail 'rule_8_state_consistency' "capability declares maturity: L4 while manifest.rule_8.state=fail_closed_artifact_missing" $statusPath ($i + 1)
    }
    if ($line -match '^\s+(status|evidence_state):\s*operator_gated\b') {
      Fail 'rule_8_state_consistency' "capability declares operator_gated while manifest.rule_8.state=fail_closed_artifact_missing" $statusPath ($i + 1)
    }
    if ($line -match '^\s+(status|evidence_state):\s*released\b') {
      Fail 'rule_8_state_consistency' "capability declares released while manifest.rule_8.state=fail_closed_artifact_missing" $statusPath ($i + 1)
    }
  }
  $deliveryFiles2 = Get-ChildItem -Path 'docs/delivery' -Filter '????-??-??-*.md' -File -ErrorAction SilentlyContinue
  foreach ($df in $deliveryFiles2) {
    $dRaw = Get-Content -Raw -LiteralPath $df.FullName
    if ($dRaw -match 'Rule\s*8\s*PASS') {
      if (-not ($dRaw -match '(NOT Rule 8 PASS|not Rule 8 PASS|fails closed|fail-closed|fail_closed_artifact_missing|FAIL_ARTIFACT_MISSING)')) {
        Fail 'rule_8_state_consistency' "delivery file claims Rule 8 PASS while manifest.rule_8.state=fail_closed_artifact_missing" (Rel $df.FullName) 0
      }
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

# 24. CI no-or-true mask (cycle-14 A1): gate/run_* calls in CI workflows
# must not be masked with || true. Removes the escape hatch that allowed a
# failing Rule 8 smoke gate to silently pass CI.
$wfFiles = Get-ChildItem -Path '.github/workflows' -Filter '*.yml' -File -ErrorAction SilentlyContinue
foreach ($wf in $wfFiles) {
  $wfLines = Get-Content -LiteralPath $wf.FullName
  for ($wi = 0; $wi -lt $wfLines.Count; $wi++) {
    $wLine = $wfLines[$wi]
    if ($wLine -match 'gate/run_' -and $wLine -match '\|\|\s*true') {
      Fail 'ci_no_or_true_mask' "CI workflow masks gate/run_* with '|| true' -- remove the mask or rename the step to *_report_only" (Rel $wf.FullName) ($wi + 1)
    }
  }
}

# 25. Rule 8 state machine coherent (cycle-14 B1): artifact_present_state
# must agree with rule_8.state. Prevents internally-contradictory manifests.
if (Test-Path $manifestPath) {
  $manifestText2 = Get-Content -Raw -LiteralPath $manifestPath
  $artifactPresentState = ''
  if ($manifestText2 -match '(?m)^artifact_present_state:\s*(\S+)') {
    $artifactPresentState = ($matches[1] -replace '\s*#.*$','').Trim()
  }
  if ($artifactPresentState -ne '' -and $rule8State -ne '') {
    switch ($artifactPresentState) {
      'none' {
        if ($rule8State -ne 'fail_closed_artifact_missing') {
          Fail 'rule_8_state_machine_coherent' "artifact_present_state=none but rule_8.state=$rule8State (expected fail_closed_artifact_missing)" $manifestPath 0
        }
      }
      'source_only' {
        if ($rule8State -ne 'fail_closed_needs_build') {
          Fail 'rule_8_state_machine_coherent' "artifact_present_state=source_only but rule_8.state=$rule8State (expected fail_closed_needs_build)" $manifestPath 0
        }
      }
      'jar_present' {
        if ($rule8State -ne 'fail_closed_needs_real_flow' -and $rule8State -ne 'pass') {
          Fail 'rule_8_state_machine_coherent' "artifact_present_state=jar_present but rule_8.state=$rule8State (expected fail_closed_needs_real_flow or pass)" $manifestPath 0
        }
      }
      default {
        Fail 'rule_8_state_machine_coherent' "artifact_present_state has unknown value: $artifactPresentState (valid: none | source_only | jar_present)" $manifestPath 0
      }
    }
  }
}

  # 26. Contract catalog present (cycle-15/16 D1)
  $contractCatalog = Join-Path $repoRoot 'docs/contracts/contract-catalog.md'
  if (-not (Test-Path $contractCatalog)) {
    Fail 'contract_catalog_present' 'docs/contracts/contract-catalog.md not found; create it per T-CS-Docs' $contractCatalog 0
  }

  # 27. OpenAPI snapshot pinned (cycle-15/16 D2)
  $openapiYaml = Join-Path $repoRoot 'docs/contracts/openapi-v1.yaml'
  if (-not (Test-Path $openapiYaml)) {
    Fail 'openapi_snapshot_pinned' 'docs/contracts/openapi-v1.yaml not found; create it per T-CS-2' $openapiYaml 0
  }

  # 28. Metric naming namespace (cycle-15/16 D3)
  Get-ChildItem -Recurse -Filter '*.java' -Path $repoRoot |
    Where-Object { $_.FullName -notmatch '[\\/]target[\\/]' } |
    ForEach-Object {
      $jFile = $_.FullName
      Select-String -LiteralPath $jFile -Pattern '\.counter\("([^"]+)"' -AllMatches |
        ForEach-Object {
          foreach ($m in $_.Matches) {
            $name = $m.Groups[1].Value
            if ($name -ne '' -and -not $name.StartsWith('springai_fin')) {
              Fail 'metric_naming_namespace' "Counter name '$name' does not use springai_fin_ prefix" $jFile 0
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
if ($LocalOnly) { $evidenceValidForDelivery = $false }  # cycle-14 A2: local-only runs are never delivery-valid

if ($evidenceValidForDelivery) {
  $logDir = Join-Path $PSScriptRoot 'log'
} else {
  $logDir = Join-Path $PSScriptRoot 'log/local'
}
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$result = [pscustomobject]@{
  script                       = 'check_architecture_sync.ps1'
  version                      = 'cycle-9-truth-cut'
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
