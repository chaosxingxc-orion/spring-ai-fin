# spring-ai-fin doctor script -- Windows PowerShell
# Checks that the local environment is minimally configured for dev posture.
# Exits 0 if healthy, 1 if any required condition fails.
# Usage: pwsh gate/doctor.ps1

$ExitCode = 0

function Check-Condition($Label, $Condition, $Detail) {
    if ($Condition) {
        Write-Host "[PASS] $Label"
    } else {
        Write-Host "[FAIL] $Label -- $Detail"
        $script:ExitCode = 1
    }
}

# 1. Posture detection
$Posture = if ($env:APP_POSTURE) { $env:APP_POSTURE } else { "dev" }
Check-Condition "APP_POSTURE set (current: $Posture)" $true ""

# 2. Required env vars for non-dev postures
if ($Posture -ne "dev") {
    Check-Condition "DATABASE_URL set (required in $Posture)" `
        (-not [string]::IsNullOrEmpty($env:DATABASE_URL)) "MISSING"
    Check-Condition "OPENAI_API_KEY set (required in $Posture)" `
        (-not [string]::IsNullOrEmpty($env:OPENAI_API_KEY)) "MISSING"
}

# 3. Recent gate log
$GateLogs = Get-ChildItem gate/log -Filter "*-posix.json" -ErrorAction SilentlyContinue
if ($GateLogs.Count -gt 0) {
    $Latest = ($GateLogs | Sort-Object LastWriteTime -Descending | Select-Object -First 1).Name
    Check-Condition "Recent gate log present ($Latest)" $true ""
} else {
    Check-Condition "Recent gate log present" $false "MISSING -- run gate/check_architecture_sync.ps1 first"
}

# 4. Java available
$JavaAvailable = $null -ne (Get-Command java -ErrorAction SilentlyContinue)
Check-Condition "Java available" $JavaAvailable "MISSING -- install Java 21"

exit $ExitCode
