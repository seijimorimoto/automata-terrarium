# seiji-copilot-sync.ps1 — run every available Copilot per-category sync in order.
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
        Write-Error "seiji-copilot-sync: $Name failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

Invoke-StepIfPresent 'seiji-copilot-sync-skills.ps1'   -ChildDryRun:$DryRun
Invoke-StepIfPresent 'seiji-copilot-sync-agents.ps1'   -ChildDryRun:$DryRun
Invoke-StepIfPresent 'seiji-copilot-sync-hooks.ps1'    -ChildDryRun:$DryRun
Invoke-StepIfPresent 'seiji-copilot-sync-settings.ps1' -ChildDryRun:$DryRun

Write-Host "==> done"
