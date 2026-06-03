# Validate repository conventions for Claude Code and GitHub Copilot CLI artifacts.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot = Split-Path -Parent $ScriptDir
$errors = New-Object System.Collections.Generic.List[string]

function Add-ValidationError {
    param([string]$Message)
    $errors.Add($Message)
}

function Get-FileText {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -LiteralPath $Path -Raw
}

function Test-ReadmeContains {
    param(
        [string]$ReadmePath,
        [string]$Needle,
        [string]$Description
    )

    $text = Get-FileText -Path $ReadmePath
    if ($null -eq $text -or -not $text.Contains($Needle)) {
        Add-ValidationError "$Description missing '$Needle' in $ReadmePath"
    }
}

function Test-MarkdownTableSupportColumns {
    param(
        [string]$ReadmePath,
        [string]$Description
    )

    $text = Get-FileText -Path $ReadmePath
    if ($null -eq $text) {
        Add-ValidationError "$Description missing README: $ReadmePath"
        return
    }

    if (-not $text.Contains('Claude Code') -or -not $text.Contains('Copilot CLI')) {
        Add-ValidationError "$Description must include Claude Code and Copilot CLI support columns"
    }

    foreach ($marker in @('✅', '❌', '⚠️')) {
        if (-not $text.Contains($marker)) {
            Add-ValidationError "$Description must document/use support marker $marker"
        }
    }
}

function Get-Frontmatter {
    param([string]$Path)

    $text = Get-FileText -Path $Path
    if ($null -eq $text) { return $null }
    if (-not $text.StartsWith("---`n") -and -not $text.StartsWith("---`r`n")) {
        return $null
    }

    $normalized = $text -replace "`r`n", "`n"
    $end = $normalized.IndexOf("`n---`n", 4)
    if ($end -lt 0) { return $null }
    return $normalized.Substring(4, $end - 4)
}

function Test-CopilotSkillFrontmatter {
    param([string]$Path)

    $frontmatter = Get-Frontmatter -Path $Path
    if ($null -eq $frontmatter) {
        Add-ValidationError "Copilot skill missing YAML frontmatter: $Path"
        return
    }

    foreach ($required in @('name:', 'description:')) {
        if ($frontmatter -notmatch "(?m)^$([regex]::Escape($required))") {
            Add-ValidationError "Copilot skill missing required frontmatter '$required': $Path"
        }
    }

    if ($frontmatter -match '(?m)^hooks:') {
        Add-ValidationError "Copilot skill must not use Claude frontmatter hooks: $Path"
    }
}

function Test-CopilotAgentFrontmatter {
    param([string]$Path)

    $frontmatter = Get-Frontmatter -Path $Path
    if ($null -eq $frontmatter) {
        Add-ValidationError "Copilot agent missing YAML frontmatter: $Path"
        return
    }

    foreach ($required in @('name:', 'description:', 'tools:')) {
        if ($frontmatter -notmatch "(?m)^$([regex]::Escape($required))") {
            Add-ValidationError "Copilot agent missing required frontmatter '$required': $Path"
        }
    }

    if ($frontmatter -match '(?m)^hooks:') {
        Add-ValidationError "Copilot agent must not use Claude frontmatter hooks: $Path"
    }
}

function Test-SortedStringArray {
    param(
        [object[]]$Values,
        [string]$Path
    )

    if ($null -eq $Values -or $Values.Count -le 1) { return }
    $items = for ($i = 0; $i -lt $Values.Count; $i++) {
        [PSCustomObject]@{
            Value = [string]$Values[$i]
            SortValue = ([string]$Values[$i]) -replace ' \*\)$', ')'
            Index = $i
        }
    }
    $sorted = @($items | Sort-Object SortValue, Index | ForEach-Object { $_.Value })
    for ($i = 0; $i -lt $Values.Count; $i++) {
        if ($Values[$i] -ne $sorted[$i]) {
            Add-ValidationError "String array is not sorted: $Path"
            return
        }
    }
}

# Root instruction files.
$agentsPath = Join-Path $RepoRoot 'AGENTS.md'
$claudePath = Join-Path $RepoRoot 'CLAUDE.md'
if (-not (Test-Path -LiteralPath $agentsPath)) {
    Add-ValidationError 'AGENTS.md must exist as the canonical instruction file'
}
if (-not (Test-Path -LiteralPath $claudePath)) {
    Add-ValidationError 'CLAUDE.md must exist for Claude Code compatibility'
}
else {
    $claudeItem = Get-Item -LiteralPath $claudePath
    if ($claudeItem.LinkType -eq 'SymbolicLink') {
        $target = @($claudeItem.Target) -join ''
        if ($target -notmatch 'AGENTS\.md$') {
            Add-ValidationError "CLAUDE.md symlink must target AGENTS.md, found '$target'"
        }
    }
    elseif ((Test-Path -LiteralPath $agentsPath) -and ((Get-FileText $agentsPath) -ne (Get-FileText $claudePath))) {
        Add-ValidationError 'CLAUDE.md must be a symlink to AGENTS.md or an identical generated mirror'
    }
}

# Skill entrypoint invariants.
$skillsDir = Join-Path $RepoRoot 'skills'
if (Test-Path -LiteralPath $skillsDir) {
    Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name | ForEach-Object {
        $skillName = $_.Name
        $shared = Join-Path $_.FullName 'SKILL.md'
        $claude = Join-Path $_.FullName 'SKILL.claude.md'
        $copilot = Join-Path $_.FullName 'SKILL.copilot.md'

        $hasShared = Test-Path -LiteralPath $shared
        $hasClaude = Test-Path -LiteralPath $claude
        $hasCopilot = Test-Path -LiteralPath $copilot

        if (-not $hasShared -and -not $hasClaude -and -not $hasCopilot) {
            Add-ValidationError "Skill '$skillName' must have SKILL.md, SKILL.claude.md, and/or SKILL.copilot.md"
        }
        if ($hasShared -and ($hasClaude -or $hasCopilot)) {
            Add-ValidationError "Skill '$skillName' must not mix shared SKILL.md with target-specific SKILL.*.md files"
        }
        if ($hasCopilot) {
            Test-CopilotSkillFrontmatter -Path $copilot
        }
    }

    # Agent entrypoint invariants.
    $agentsDir = Join-Path $RepoRoot 'agents'
    if (Test-Path -LiteralPath $agentsDir) {
        Get-ChildItem -LiteralPath $agentsDir -Directory | Sort-Object Name | ForEach-Object {
            $agentName = $_.Name
            $shared = Join-Path $_.FullName "$agentName.md"
            $claude = Join-Path $_.FullName "$agentName.claude.md"
            $copilot = Join-Path $_.FullName "$agentName.copilot.md"
            $legacyCopilot = Join-Path $_.FullName "$agentName.agent.md"

            $hasShared = Test-Path -LiteralPath $shared
            $hasClaude = Test-Path -LiteralPath $claude
            $hasCopilot = Test-Path -LiteralPath $copilot

            if (-not $hasShared -and -not $hasClaude -and -not $hasCopilot) {
                Add-ValidationError "Agent '$agentName' must have $agentName.md, $agentName.claude.md, and/or $agentName.copilot.md"
            }
            if ($hasShared -and ($hasClaude -or $hasCopilot)) {
                Add-ValidationError "Agent '$agentName' must not mix shared $agentName.md with target-specific agent files"
            }
            if (Test-Path -LiteralPath $legacyCopilot) {
                Add-ValidationError "Agent '$agentName' should use source name $agentName.copilot.md, not $agentName.agent.md"
            }
            if ($hasCopilot) {
                Test-CopilotAgentFrontmatter -Path $copilot
            }
        }
    }
}

# Parent README availability coverage.
$rootReadme = Join-Path $RepoRoot 'README.md'
$skillsReadme = Join-Path $RepoRoot 'skills\README.md'
$agentsReadme = Join-Path $RepoRoot 'agents\README.md'
$hooksReadme = Join-Path $RepoRoot 'hooks\README.md'
$settingsReadme = Join-Path $RepoRoot 'settings\README.md'
$binReadme = Join-Path $RepoRoot 'bin\README.md'

foreach ($readme in @(
    @{ Path = $rootReadme; Description = 'Root README' },
    @{ Path = $skillsReadme; Description = 'Skills README' },
    @{ Path = $agentsReadme; Description = 'Agents README' },
    @{ Path = $hooksReadme; Description = 'Hooks README' },
    @{ Path = $settingsReadme; Description = 'Settings README' },
    @{ Path = $binReadme; Description = 'Bin README' }
)) {
    Test-MarkdownTableSupportColumns -ReadmePath $readme.Path -Description $readme.Description
}

Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name | ForEach-Object {
    Test-ReadmeContains -ReadmePath $rootReadme -Needle $_.Name -Description 'Root skills table'
    Test-ReadmeContains -ReadmePath $skillsReadme -Needle $_.Name -Description 'Skills table'
}

Get-ChildItem -LiteralPath $agentsDir -Directory | Sort-Object Name | ForEach-Object {
    Test-ReadmeContains -ReadmePath $rootReadme -Needle $_.Name -Description 'Root agents table'
    Test-ReadmeContains -ReadmePath $agentsReadme -Needle $_.Name -Description 'Agents table'
}

$hooksDir = Join-Path $RepoRoot 'hooks'
Get-ChildItem -LiteralPath $hooksDir -Directory | Sort-Object Name | ForEach-Object {
    Test-ReadmeContains -ReadmePath $rootReadme -Needle $_.Name -Description 'Root hooks table'
    Test-ReadmeContains -ReadmePath $hooksReadme -Needle $_.Name -Description 'Hooks table'
}

# Target-specific settings arrays should stay sorted for deterministic merges.
$settingsRoots = @(
    (Join-Path $RepoRoot 'settings\claude'),
    (Join-Path $RepoRoot 'settings\copilot')
) | Where-Object { Test-Path -LiteralPath $_ }

foreach ($settingsRoot in $settingsRoots) {
Get-ChildItem -LiteralPath $settingsRoot -Filter '*.json' -File | Sort-Object Name | ForEach-Object {
    try {
        $json = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
    }
    catch {
        Add-ValidationError "Settings preset is not valid JSON: $($_.FullName)"
        return
    }

    if ($json.permissions) {
        foreach ($property in @('allow', 'deny', 'ask')) {
            $values = @($json.permissions.$property)
            Test-SortedStringArray -Values $values -Path "$($_.Name): permissions.$property"
        }
    }
}
}

if ($errors.Count -gt 0) {
    Write-Error ("Validation failed:`n- " + ($errors -join "`n- "))
    exit 1
}

Write-Host 'Validation passed.'
