# seiji-claude-sync-skills.ps1 — copy each <repo>\skills\<name>\ to ~\.claude\skills\<name>\
# Use -DryRun to preview without writing.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$SrcDir    = Join-Path $RepoRoot 'skills'
$DstDir    = Join-Path $HOME '.claude\skills'

if (-not (Test-Path -LiteralPath $SrcDir)) {
    Write-Error "seiji-claude-sync-skills: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

$count = 0
Get-ChildItem -LiteralPath $SrcDir -Directory | Sort-Object Name | ForEach-Object {
    $src  = $_.FullName
    $name = $_.Name
    $dst  = Join-Path $DstDir $name
    if ($DryRun) {
        Write-Host "[dry-run] sync skill '$name': $src -> $dst"
    }
    else {
        if (Test-Path -LiteralPath $dst) {
            Remove-Item -LiteralPath $dst -Recurse -Force
        }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        Write-Host "synced skill '$name'"
    }
    $count++
}

if ($DryRun) {
    Write-Host "[dry-run] would sync $count skill(s) to $DstDir"
}
else {
    Write-Host "synced $count skill(s) to $DstDir"
}
