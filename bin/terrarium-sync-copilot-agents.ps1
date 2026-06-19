# terrarium-sync-copilot-agents.ps1 — copy Copilot custom agent profiles to ~\.copilot\agents\
# Use -DryRun to preview without writing.
# Source files use <name>.copilot.md and install as <name>.agent.md.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$SrcDir    = Join-Path $RepoRoot 'agents'
$DstDir    = Join-Path $HOME '.copilot\agents'

if (-not (Test-Path -LiteralPath $SrcDir)) {
    Write-Error "terrarium-sync-copilot-agents: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

$count = 0

Get-ChildItem -LiteralPath $SrcDir -Filter '*.copilot.md' -File | Sort-Object Name | ForEach-Object {
    $src = $_.FullName
    $dstName = $_.Name -replace '\.copilot\.md$', '.agent.md'
    $dst = Join-Path $DstDir $dstName
    if ($DryRun) {
        Write-Host "[dry-run] sync Copilot agent '$($_.Name)': $src -> $dst"
    }
    else {
        Copy-Item -LiteralPath $src -Destination $dst -Force
        Write-Host "synced Copilot agent '$($_.Name)'"
    }
    $count++
}

Get-ChildItem -LiteralPath $SrcDir -Directory | Sort-Object Name | ForEach-Object {
    $agentFile = Join-Path $_.FullName "$($_.Name).copilot.md"
    if (-not (Test-Path -LiteralPath $agentFile)) { return }

    $dst = Join-Path $DstDir "$($_.Name).agent.md"
    if ($DryRun) {
        Write-Host "[dry-run] sync Copilot agent '$($_.Name)': $agentFile -> $dst"
    }
    else {
        Copy-Item -LiteralPath $agentFile -Destination $dst -Force
        Write-Host "synced Copilot agent '$($_.Name)'"
    }
    $count++
}

if ($DryRun) {
    Write-Host "[dry-run] would sync $count Copilot agent(s) to $DstDir"
}
else {
    Write-Host "synced $count Copilot agent(s) to $DstDir"
}
