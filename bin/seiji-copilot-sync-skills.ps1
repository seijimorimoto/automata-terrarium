# seiji-copilot-sync-skills.ps1 — copy each Copilot-compatible skill to ~\.copilot\skills\<name>\
# Use -DryRun to preview without writing.
# If a skill uses split entrypoints, SKILL.copilot.md is installed as SKILL.md.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$SrcDir    = Join-Path $RepoRoot 'skills'
$DstDir    = Join-Path $HOME '.copilot\skills'

if (-not (Test-Path -LiteralPath $SrcDir)) {
    Write-Error "seiji-copilot-sync-skills: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

function Copy-SkillForCopilot {
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

    $copilotSkill = Join-Path $Source 'SKILL.copilot.md'
    if (Test-Path -LiteralPath $copilotSkill) {
        Copy-Item -LiteralPath $copilotSkill -Destination (Join-Path $Destination 'SKILL.md') -Force
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

    if ($usesSplitSkill -and -not (Test-Path -LiteralPath $copilotSkill)) {
        if ($DryRun) {
            Write-Host "[dry-run] skip skill '$name' (no Copilot entrypoint)"
        }
        else {
            Write-Host "skipped skill '$name' (no Copilot entrypoint)"
        }
        return
    }

    if ($DryRun) {
        $mode = if ($usesSplitSkill) { 'copilot variant' } else { 'shared' }
        Write-Host "[dry-run] sync skill '$name' ($mode): $src -> $dst"
    }
    else {
        if ($usesSplitSkill) {
            Copy-SkillForCopilot -Source $src -Destination $dst
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
