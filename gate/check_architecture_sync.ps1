#!/usr/bin/env pwsh
<#
.SYNOPSIS
  DEPRECATED PowerShell entrypoint for the spring-ai-ascend architecture-sync gate.

.DESCRIPTION
  As of v2.0.0-rc2 (2026-05-16), the PowerShell architecture-sync gate is
  deprecated and fail-closed. It was frozen at Rule 29 in 2026-05 while the
  bash gate evolved through Rules 28a-28k + 30-60 (W1 Layered 4+1, W1.x L0
  ironclad rules, W2.x Engine Contract Structural Wave). The PowerShell entry-
  point had no self-test harness and was never run in CI, so a green run here
  did not match the canonical release gate.

  The canonical L0 release gate is:

      bash gate/check_architecture_sync.sh

  Run it from Git Bash, WSL, or any POSIX shell on Windows. Self-tests:

      bash gate/test_architecture_sync_gate.sh

  Authority for deprecation: v2.0.0-rc1 second-pass architecture review
  finding P0-1 (docs/reviews/2026-05-16-l0-w2x-rc1-second-pass-architecture-
  review.en.md) and the rc2 response (docs/reviews/2026-05-17-l0-w2x-rc1-
  second-pass-review-response.en.md). Gate Rule 61
  (`legacy_powershell_gate_deprecated`) asserts this stub remains in place.
#>

[CmdletBinding()]
param(
  [switch]$LocalOnly
)

Write-Host "DEPRECATED: gate/check_architecture_sync.ps1 was frozen at Rule 29 in 2026-05."
Write-Host "The canonical L0 release gate is bash:"
Write-Host ""
Write-Host "    bash gate/check_architecture_sync.sh"
Write-Host ""
Write-Host "Self-tests:"
Write-Host ""
Write-Host "    bash gate/test_architecture_sync_gate.sh"
Write-Host ""
Write-Host "See docs/reviews/2026-05-17-l0-w2x-rc1-second-pass-review-response.en.md (P0-1)."
exit 2
