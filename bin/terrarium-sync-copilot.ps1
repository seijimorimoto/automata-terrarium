# terrarium-sync-copilot.ps1 — run every available Copilot per-category sync in order.
#
# Order as categories are implemented: skills -> agents -> hooks -> settings.
# Pass -DryRun to preview without writing.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath

function Invoke-StepIfPresent {
    param(
        [string]$Name,
        [switch]$ChildDryRun
    )

    $script = Join-Path $ScriptDir $Name
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Host "==> skip $Name (not implemented yet)"
        return
    }

    Write-Host "==> $Name"
    if ($ChildDryRun) { & $script -DryRun }
    else              { & $script }

    if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -gt 0) {
        Write-Error "terrarium-sync-copilot: $Name failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

Invoke-StepIfPresent 'terrarium-sync-copilot-skills.ps1'   -ChildDryRun:$DryRun
Invoke-StepIfPresent 'terrarium-sync-copilot-agents.ps1'   -ChildDryRun:$DryRun
Invoke-StepIfPresent 'terrarium-sync-copilot-hooks.ps1'    -ChildDryRun:$DryRun
Invoke-StepIfPresent 'terrarium-sync-copilot-settings.ps1' -ChildDryRun:$DryRun

Write-Host "==> done"
