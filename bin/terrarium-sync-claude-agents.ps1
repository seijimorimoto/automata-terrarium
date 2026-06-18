# terrarium-sync-claude-agents.ps1 — copy <repo>\agents\ entries to ~\.claude\agents\.
# Use -DryRun to preview without writing.
#
# Two layouts are supported:
#   - Flat:    agents\<name>.md                 -> ~\.claude\agents\<name>.md
#   - Folder:  agents\<name>\<name>.claude.md   -> ~\.claude\agents\<name>\<name>.md
#   - Folder:  agents\<name>\<name>.md          -> ~\.claude\agents\<name>\<name>.md
# Copilot custom agent source profiles (*.copilot.md) are excluded from Claude installs.
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
    Write-Error "terrarium-sync-claude-agents: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

function Copy-AgentForClaude {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Name
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        if (-not $_.PSIsContainer -and $_.Name -in @("$Name.claude.md", "$Name.copilot.md")) { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name) -Recurse -Force
    }

    $claudeAgent = Join-Path $Source "$Name.claude.md"
    if (Test-Path -LiteralPath $claudeAgent) {
        Copy-Item -LiteralPath $claudeAgent -Destination (Join-Path $Destination "$Name.md") -Force
    }
}

$count = 0

# Flat .md agent files at the top of agents\
Get-ChildItem -LiteralPath $SrcDir -Filter '*.md' -File | Sort-Object Name | ForEach-Object {
    if ($_.Name -ieq 'README.md') { return }
    if ($_.Name -like '*.copilot.md' -or $_.Name -like '*.claude.md') { return }
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
    $claudeAgent = Join-Path $src "$name.claude.md"
    $sharedAgent = Join-Path $src "$name.md"
    if ($DryRun) {
        $mode = if (Test-Path -LiteralPath $claudeAgent) { 'claude variant' } else { 'shared' }
        Write-Host "[dry-run] sync agent '$name' (folder, $mode): $src -> $dst"
    }
    else {
        if (-not (Test-Path -LiteralPath $claudeAgent) -and -not (Test-Path -LiteralPath $sharedAgent)) {
            Write-Error "terrarium-sync-claude-agents: agent '$name' is missing $name.claude.md or $name.md"
            exit 1
        }
        Copy-AgentForClaude -Source $src -Destination $dst -Name $name
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
