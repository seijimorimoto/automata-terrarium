# terrarium-sync-claude-hooks.ps1 — copy each <repo>\hooks\<name>\ to ~\.claude\hooks\<name>\
# Use -DryRun to preview without writing.
#
# This script copies hook scripts only. It does NOT register hooks in
# ~\.claude\settings.json. Checked-in claude.hooks.json files are
# registration templates; safe registration/merge automation is tracked by #22.
# Only Claude hook JSON files are included. The hook JSON files of any other
# agent orchestrator are excluded.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$SrcDir    = Join-Path $RepoRoot 'hooks'
$DstDir    = Join-Path $HOME '.claude\hooks'

if (-not (Test-Path -LiteralPath $SrcDir)) {
    Write-Error "terrarium-sync-claude-hooks: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

function Copy-HookForClaude {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        if (-not $_.PSIsContainer -and $_.Name -like '*.hooks.json' -and $_.Name -ne 'claude.hooks.json') { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name) -Recurse -Force
    }
}

$count = 0
Get-ChildItem -LiteralPath $SrcDir -Directory | Sort-Object Name | ForEach-Object {
    $src  = $_.FullName
    $name = $_.Name
    $dst  = Join-Path $DstDir $name
    if ($DryRun) {
        Write-Host "[dry-run] sync hook '$name': $src -> $dst"
    }
    else {
        Copy-HookForClaude -Source $src -Destination $dst
        Write-Host "synced hook '$name'"
    }
    $count++
}

if ($DryRun) {
    Write-Host "[dry-run] would sync $count hook(s) to $DstDir"
}
else {
    Write-Host "synced $count hook(s) to $DstDir"
}
