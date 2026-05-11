#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-ascend architecture-sync gate -- Occam's Razor cut (C24, 6 rules).

.DESCRIPTION
  Replaces the 27-rule corpus. Exits 0 if all 6 pass, 1 if any fail.
  Each rule prints PASS: <name> or FAIL: <name> -- <reason>.
  Prints GATE: PASS or GATE: FAIL at the end.

  Rules:
    1. status_enum_invalid      -- architecture-status.yaml status values
    2. delivery_log_parity      -- gate/log/*.json sha field matches filename
    3. eol_policy               -- *.sh files in gate/ must be LF (not CRLF)
    4. ci_no_or_true_mask       -- no gate/run_* || true in CI workflows
    5. required_files_present   -- contract-catalog.md and openapi-v1.yaml must exist
    6. metric_naming_namespace  -- springai_ascend_ prefix in Java metric names

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
# Summary
# ---------------------------------------------------------------------------
if ($failCount -eq 0) {
  Write-Host 'GATE: PASS'
  exit 0
} else {
  Write-Host 'GATE: FAIL'
  exit 1
}
