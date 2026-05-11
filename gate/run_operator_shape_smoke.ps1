#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-ascend Rule 8 operator-shape smoke gate — Windows entry point.

.DESCRIPTION
  This is the FIRST Rule 8 gate per CLAUDE.md / AGENTS.md Rule 8 and
  docs/systematic-architecture-remediation-plan-2026-05-08-cycle-4.en.md §D1.

  Currently fails closed because the runnable artifact does not exist (W0
  has not landed yet). When W0 produces the Maven multi-module + minimal
  Spring Boot, this script will be replaced with the real smoke flow:

    1. build the runnable artifact (mvn -q package)
    2. start a long-lived managed process
    3. use real local Postgres
    4. hit /health and /ready
    5. perform N>=3 sequential POST /v1/runs
    6. prove resource reuse + lifecycle observability
    7. cancel a live run and drive it terminal (200)
    8. cancel an unknown run -> 404
    9. assert *_fallback_total == 0 on the happy path
    10. write gate/log/operator-shape/<sha>.json with evidence_valid_for_delivery=true
    11. write docs/delivery/<date>-<sha>.md

  Until then, the script writes a fail-closed artifact-missing log under
  gate/log/local/ (gitignored) and exits 1.

.NOTES
  There is NO --LocalOnly mode for the operator-shape gate. Dirty trees are
  never valid Rule 8 evidence.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot

$shaCandidate = ''
try { $shaCandidate = ((& git rev-parse --short HEAD 2>$null) -join '').Trim() } catch { $shaCandidate = 'no-git' }
if ([string]::IsNullOrEmpty($shaCandidate)) { $shaCandidate = 'no-git' }

# Cycle-13 (Phase B step 1): tri-state fail-closed.
$manifestProbes = @(
  @{ Path = 'pom.xml'; Reason = 'no Maven build manifest at repo root' },
  @{ Path = 'agent-platform/pom.xml'; Reason = 'no Maven build manifest under agent-platform/' },
  @{ Path = 'agent-runtime/pom.xml'; Reason = 'no Maven build manifest under agent-runtime/' }
)
$sourceProbes = @(
  @{ Path = 'agent-platform/src/main/java'; Reason = 'no source tree under agent-platform/' },
  @{ Path = 'agent-runtime/src/main/java'; Reason = 'no source tree under agent-runtime/' }
)
$missing = New-Object System.Collections.ArrayList
$manifestsPresent = $true
$sourcesPresent = $true
foreach ($p in $manifestProbes) {
  if (-not (Test-Path -LiteralPath $p.Path)) {
    [void]$missing.Add([pscustomobject]@{ path = $p.Path; reason = $p.Reason })
    $manifestsPresent = $false
  }
}
foreach ($p in $sourceProbes) {
  if (-not (Test-Path -LiteralPath $p.Path)) {
    [void]$missing.Add([pscustomobject]@{ path = $p.Path; reason = $p.Reason })
    $sourcesPresent = $false
  }
}
$jarPresent = $false
if (Test-Path 'agent-platform/target') {
  $jars = Get-ChildItem -Path 'agent-platform/target' -Filter 'agent-platform-*.jar' -File -ErrorAction SilentlyContinue
  if ($jars -and $jars.Count -gt 0) { $jarPresent = $true }
}

if (-not $manifestsPresent -or -not $sourcesPresent) {
  $outcome = 'FAIL_ARTIFACT_MISSING'
  $message = 'Rule 8 operator-shape smoke gate fails closed: pom.xml or src tree missing. Pre-cycle-13 state.'
} elseif (-not $jarPresent) {
  $outcome = 'FAIL_NEEDS_BUILD'
  $message = "Rule 8 operator-shape smoke gate fails closed: pom.xml + src present but no built JAR under agent-platform/target/. Run 'mvn -B -pl agent-platform -am package' to advance. Real Rule 8 flow remains a W4 deliverable."
} else {
  $outcome = 'FAIL_NEEDS_REAL_FLOW'
  $message = 'Rule 8 operator-shape smoke gate fails closed: JAR exists but no real-flow run yet. Real Rule 8 flow (long-lived process + real dependencies + sequential N>=3 + lifecycle observability + cancellation round-trip + zero fallback) remains a W4 deliverable.'
}

$artifactPresent = ($manifestsPresent -and $sourcesPresent)

$logDir = Join-Path $PSScriptRoot 'log/local'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir "operator-shape-$shaCandidate-windows.json"

$result = [pscustomobject]@{
  script                       = 'run_operator_shape_smoke.ps1'
  version                      = 'cycle-13-tri-state'
  kind                         = 'operator_shape_smoke'
  sha                          = $shaCandidate
  generated                    = (Get-Date -Format 'o')
  manifests_present            = $manifestsPresent
  sources_present              = $sourcesPresent
  jar_present                  = $jarPresent
  artifact_present             = $artifactPresent
  missing_artifacts            = $missing
  outcome                      = $outcome
  evidence_valid_for_delivery  = $false
  rule_8_evidence              = $false
  message                      = $message
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logPath -Encoding UTF8

Write-Host "FAIL ($outcome): operator-shape smoke gate. Log: $logPath" -ForegroundColor Red
Write-Host ($result | ConvertTo-Json -Depth 4)
exit 1
