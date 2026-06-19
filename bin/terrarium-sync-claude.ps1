# terrarium-sync-claude.ps1 — run every per-category sync in order.
#
# Order: skills -> agents -> hooks -> settings. Settings runs last so
# that any hook registrations referencing scripts have the script files
# in place first. Pass -DryRun to preview without writing.
# Pass -NoBackup to skip the settings-file backup (forwarded to
# terrarium-sync-claude-settings.ps1 only — the other steps don't make backups).
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath

function Invoke-Step {
    param(
        [string]$Name,
        [switch]$ChildDryRun,
        [switch]$ChildNoBackup
    )
    $script = Join-Path $ScriptDir $Name
    if (-not (Test-Path -LiteralPath $script)) {
        Write-Error "terrarium-sync-claude: missing $Name"
        exit 1
    }
    Write-Host "==> $Name"
    # Explicit invocation per flag combination — splatting an array of
    # switch-style strings (`@('-DryRun')`) gets parsed by PowerShell as
    # positional args in some contexts, which the children then reject.
    if     ($ChildDryRun -and $ChildNoBackup) { & $script -DryRun -NoBackup }
    elseif ($ChildDryRun)                     { & $script -DryRun }
    elseif ($ChildNoBackup)                   { & $script -NoBackup }
    else                                       { & $script }
    # PowerShell scripts invoked with & don't reliably set $LASTEXITCODE
    # (it's only set for native exes), so we rely on $ErrorActionPreference
    # = 'Stop' propagating errors from the child script into here. If a
    # child does call `exit N` with N > 0, we honour it.
    if ($LASTEXITCODE -is [int] -and $LASTEXITCODE -gt 0) {
        Write-Error "terrarium-sync-claude: $Name failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}

Invoke-Step 'terrarium-sync-claude-skills.ps1'   -ChildDryRun:$DryRun
Invoke-Step 'terrarium-sync-claude-agents.ps1'   -ChildDryRun:$DryRun
Invoke-Step 'terrarium-sync-claude-hooks.ps1'    -ChildDryRun:$DryRun
Invoke-Step 'terrarium-sync-claude-settings.ps1' -ChildDryRun:$DryRun -ChildNoBackup:$NoBackup

Write-Host "==> done"
