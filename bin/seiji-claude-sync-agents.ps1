# seiji-claude-sync-agents.ps1 — copy <repo>\agents\ entries to ~\.claude\agents\.
# Use -DryRun to preview without writing.
#
# Two layouts are supported:
#   - Flat:    agents\<name>.md            -> ~\.claude\agents\<name>.md
#   - Folder:  agents\<name>\<files...>    -> ~\.claude\agents\<name>\<files...>
#
# The folder layout co-locates an agent's resources (e.g., hook scripts the
# agent registers via its frontmatter) with the agent definition itself.
# README.md at the top of agents\ is repo documentation and is skipped.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$SrcDir    = Join-Path $RepoRoot 'agents'
$DstDir    = Join-Path $HOME '.claude\agents'

if (-not (Test-Path -LiteralPath $SrcDir)) {
    Write-Error "seiji-claude-sync-agents: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

$count = 0

# Flat .md agent files at the top of agents\
Get-ChildItem -LiteralPath $SrcDir -Filter '*.md' -File | Sort-Object Name | ForEach-Object {
    if ($_.Name -ieq 'README.md') { return }
    $src  = $_.FullName
    $name = $_.Name
    $dst  = Join-Path $DstDir $name
    if ($DryRun) {
        Write-Host "[dry-run] sync agent '$name' (flat): $src -> $dst"
    }
    else {
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host "synced agent '$name' (flat)"
    }
    $count++
}

# Folder-style agents (each subfolder under agents\ becomes one user-level agent dir)
Get-ChildItem -LiteralPath $SrcDir -Directory | Sort-Object Name | ForEach-Object {
    $src  = $_.FullName
    $name = $_.Name
    $dst  = Join-Path $DstDir $name
    if ($DryRun) {
        Write-Host "[dry-run] sync agent '$name' (folder): $src -> $dst"
    }
    else {
        if (Test-Path -LiteralPath $dst) {
            Remove-Item -LiteralPath $dst -Recurse -Force
        }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        Write-Host "synced agent '$name' (folder)"
    }
    $count++
}

if ($DryRun) {
    Write-Host "[dry-run] would sync $count agent(s) to $DstDir"
}
else {
    Write-Host "synced $count agent(s) to $DstDir"
}
