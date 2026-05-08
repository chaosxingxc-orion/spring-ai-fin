#!/usr/bin/env pwsh
<#
.SYNOPSIS
  spring-ai-fin Rule 8 operator-shape smoke gate — Windows entry point.

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

# Pre-W0: artifact missing. Probe once for clarity.
$artifactProbes = @(
  @{ Path = 'pom.xml'; Reason = 'no Maven build manifest at repo root' },
  @{ Path = 'agent-platform/pom.xml'; Reason = 'no Maven build manifest under agent-platform/' },
  @{ Path = 'agent-runtime/pom.xml'; Reason = 'no Maven build manifest under agent-runtime/' },
  @{ Path = 'agent-platform/src/main/java'; Reason = 'no source tree under agent-platform/' },
  @{ Path = 'agent-runtime/src/main/java'; Reason = 'no source tree under agent-runtime/' }
)
$missing = New-Object System.Collections.ArrayList
foreach ($probe in $artifactProbes) {
  if (-not (Test-Path -LiteralPath $probe.Path)) {
    [void]$missing.Add([pscustomobject]@{ path = $probe.Path; reason = $probe.Reason })
  }
}

$logDir = Join-Path $PSScriptRoot 'log/local'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$logPath = Join-Path $logDir "operator-shape-$shaCandidate-windows.json"

$result = [pscustomobject]@{
  script                       = 'run_operator_shape_smoke.ps1'
  version                      = 'cycle-4-fail-closed'
  kind                         = 'operator_shape_smoke'
  sha                          = $shaCandidate
  generated                    = (Get-Date -Format 'o')
  artifact_present             = ($missing.Count -eq 0)
  missing_artifacts            = $missing
  outcome                      = 'FAIL_ARTIFACT_MISSING'
  evidence_valid_for_delivery  = $false
  rule_8_evidence              = $false
  message                      = 'Rule 8 operator-shape smoke gate fails closed: no runnable artifact exists yet. W0 deliverable per docs/plans/W0-evidence-skeleton.md. Architecture-sync evidence (gate/check_architecture_sync.*) does NOT substitute for Rule 8 evidence.'
}
$result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logPath -Encoding UTF8

Write-Host "FAIL: operator-shape smoke gate has no runnable artifact (W0 deliverable). Log: $logPath" -ForegroundColor Red
Write-Host ($result | ConvertTo-Json -Depth 4)
exit 1
