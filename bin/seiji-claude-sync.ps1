# seiji-claude-sync.ps1 — run every per-category sync in order.
#
# Order: skills -> hooks -> settings. Settings runs last so that any hook
# registrations referencing scripts have the script files in place first.
# Pass -DryRun to preview without writing.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath

function Invoke-Step {
    param([string]$Name)
    $script = Join-Path $ScriptDir $Name
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Error "seiji-claude-sync: missing $Name"
        exit 1
    }
    Write-Host "==> $Name"
    if ($DryRun) {
        & $script -DryRun
    }
    else {
        & $script
    }
    # PowerShell scripts invoked with & don't reliably set $LASTEXITCODE
    # (it's only set for native exes), so we rely on $ErrorActionPreference
    # = 'Stop' propagating errors from the child script into here. If a
    # child does call `exit N` with N > 0, we honour it.
    if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -gt 0) {
        Write-Error "seiji-claude-sync: $Name failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

Invoke-Step 'seiji-claude-sync-skills.ps1'
Invoke-Step 'seiji-claude-sync-hooks.ps1'
Invoke-Step 'seiji-claude-sync-settings.ps1'

Write-Host "==> done"
