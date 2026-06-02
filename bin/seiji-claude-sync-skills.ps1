# seiji-claude-sync-skills.ps1 — copy each <repo>\skills\<name>\ to ~\.claude\skills\<name>\
# Use -DryRun to preview without writing.
# If a skill uses split entrypoints, SKILL.claude.md is installed as SKILL.md.
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

function Copy-SkillForClaude {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        if ($_.Name -in @('SKILL.claude.md', 'SKILL.copilot.md')) { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name) -Recurse -Force
    }

    $claudeSkill = Join-Path $Source 'SKILL.claude.md'
    if (Test-Path -LiteralPath $claudeSkill) {
        Copy-Item -LiteralPath $claudeSkill -Destination (Join-Path $Destination 'SKILL.md') -Force
    }
}

$count = 0
Get-ChildItem -LiteralPath $SrcDir -Directory | Sort-Object Name | ForEach-Object {
    $src  = $_.FullName
    $name = $_.Name
    $dst  = Join-Path $DstDir $name
    $claudeSkill = Join-Path $src 'SKILL.claude.md'
    $copilotSkill = Join-Path $src 'SKILL.copilot.md'
    $usesSplitSkill = (Test-Path -LiteralPath $claudeSkill) -or (Test-Path -LiteralPath $copilotSkill)
    if ($DryRun) {
        $mode = if ($usesSplitSkill) { 'claude variant' } else { 'shared' }
        Write-Host "[dry-run] sync skill '$name' ($mode): $src -> $dst"
    }
    else {
        if ($usesSplitSkill) {
            if (-not (Test-Path -LiteralPath $claudeSkill)) {
                Write-Error "seiji-claude-sync-skills: skill '$name' has split entrypoints but is missing SKILL.claude.md"
                exit 1
            }
            Copy-SkillForClaude -Source $src -Destination $dst
        }
        else {
            if (Test-Path -LiteralPath $dst) {
                Remove-Item -LiteralPath $dst -Recurse -Force
            }
            Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
        }
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
