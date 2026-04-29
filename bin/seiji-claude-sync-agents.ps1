# seiji-claude-sync-agents.ps1 — copy each <repo>\agents\*.md to ~\.claude\agents\.
# Use -DryRun to preview without writing.
#
# Agents are single markdown files with YAML frontmatter — they don't
# live in subfolders. This sync mirrors that file-level shape: each
# agents\<name>.md becomes ~\.claude\agents\<name>.md.
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
Get-ChildItem -LiteralPath $SrcDir -Filter '*.md' -File | Sort-Object Name | ForEach-Object {
    if ($_.Name -ieq 'README.md') { return }
    $src  = $_.FullName
    $name = $_.Name
    $dst  = Join-Path $DstDir $name
    if ($DryRun) {
        Write-Host "[dry-run] sync agent '$name': $src -> $dst"
    }
    else {
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host "synced agent '$name'"
    }
    $count++
}

if ($DryRun) {
    Write-Host "[dry-run] would sync $count agent(s) to $DstDir"
}
else {
    Write-Host "synced $count agent(s) to $DstDir"
}
