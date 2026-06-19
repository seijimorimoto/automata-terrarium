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

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($RepoRoot, $Path).Replace('/', '\')
}

function Get-FileText {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    return Get-Content -LiteralPath $Path -Raw
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

function Split-MarkdownRow {
    param([string]$Line)

    $trimmed = $Line.Trim()
    if (-not $trimmed.StartsWith('|')) { return @() }
    $trimmed = $trimmed.Trim('|')
    return @($trimmed -split '\|' | ForEach-Object { $_.Trim() })
}

function Normalize-TableKey {
    param([string]$Cell)

    $value = $Cell
    $value = $value -replace '\[([^\]]+)\]\([^)]+\)', '$1'
    $value = $value -replace '<[^>]+>', ''
    $value = $value.Trim()
    $value = $value.Trim('`')
    $value = $value.Trim('/')
    $value = $value -replace '\\', '/'
    $value = $value.ToLowerInvariant()
    $value = $value -replace '\s+', '-'
    if ($value -eq '.net' -or $value -eq 'net') { return 'dotnet' }
    return $value
}

function Get-SupportRows {
    param([string]$ReadmePath)

    $rows = @{}
    $text = Get-FileText -Path $ReadmePath
    if ($null -eq $text) { return $rows }

    $lines = $text -replace "`r`n", "`n" -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].TrimStart().StartsWith('|')) { continue }
        $headers = Split-MarkdownRow -Line $lines[$i]
        $claudeIndex = [array]::IndexOf($headers, 'Claude Code')
        $copilotIndex = [array]::IndexOf($headers, 'Copilot CLI')
        if ($claudeIndex -lt 0 -or $copilotIndex -lt 0) { continue }

        $rowIndex = $i + 2
        while ($rowIndex -lt $lines.Count -and $lines[$rowIndex].TrimStart().StartsWith('|')) {
            $cells = Split-MarkdownRow -Line $lines[$rowIndex]
            if ($cells.Count -le [Math]::Max($claudeIndex, $copilotIndex)) {
                $rowIndex++
                continue
            }
            $key = Normalize-TableKey -Cell $cells[0]
            if (-not [string]::IsNullOrWhiteSpace($key)) {
                $rows[$key] = [PSCustomObject]@{
                    Key = $key
                    Claude = $cells[$claudeIndex]
                    Copilot = $cells[$copilotIndex]
                    Source = Get-RelativePath -Path $ReadmePath
                }
            }
            $rowIndex++
        }
    }
    return $rows
}

function Test-MarkerLegend {
    param(
        [string]$ReadmePath,
        [string]$Description
    )

    $text = Get-FileText -Path $ReadmePath
    if ($null -eq $text) {
        Add-ValidationError "$Description missing README: $ReadmePath"
        return
    }

    if ($text -notmatch '\|\s*Claude Code\s*\|' -or $text -notmatch '\|\s*Copilot CLI\s*\|') {
        Add-ValidationError "$Description must include an availability table with Claude Code and Copilot CLI columns"
        return
    }

    foreach ($marker in @('✅', '❌', '⚠️', '🛠️')) {
        if (-not $text.Contains("| $marker |")) {
            Add-ValidationError "$Description must include marker legend entry $marker"
        }
    }
}

function Compare-SupportRows {
    param(
        [string]$Description,
        [hashtable]$RootRows,
        [hashtable]$CategoryRows,
        [string[]]$ExpectedKeys
    )

    foreach ($key in $ExpectedKeys) {
        $normalized = Normalize-TableKey -Cell $key
        if (-not $RootRows.ContainsKey($normalized)) {
            Add-ValidationError "Root README missing $Description availability row '$key'"
            continue
        }
        if (-not $CategoryRows.ContainsKey($normalized)) {
            Add-ValidationError "$Description README missing availability row '$key'"
            continue
        }

        $root = $RootRows[$normalized]
        $category = $CategoryRows[$normalized]
        if ($root.Claude -ne $category.Claude -or $root.Copilot -ne $category.Copilot) {
            Add-ValidationError "$Description availability mismatch for '$key': root=($($root.Claude), $($root.Copilot)) category=($($category.Claude), $($category.Copilot))"
        }
    }
}

function Test-CopilotSkillFrontmatter {
    param([string]$Path)

    $frontmatter = Get-Frontmatter -Path $Path
    if ($null -eq $frontmatter) {
        Add-ValidationError "Copilot skill missing YAML frontmatter: $(Get-RelativePath $Path)"
        return
    }

    foreach ($required in @('name:', 'description:')) {
        if ($frontmatter -notmatch "(?m)^$([regex]::Escape($required))") {
            Add-ValidationError "Copilot skill missing required frontmatter '$required': $(Get-RelativePath $Path)"
        }
    }

    if ($frontmatter -match '(?m)^hooks:') {
        Add-ValidationError "Copilot skill must not use Claude frontmatter hooks: $(Get-RelativePath $Path)"
    }
}

function Test-CopilotAgentFrontmatter {
    param([string]$Path)

    $frontmatter = Get-Frontmatter -Path $Path
    if ($null -eq $frontmatter) {
        Add-ValidationError "Copilot agent missing YAML frontmatter: $(Get-RelativePath $Path)"
        return
    }

    foreach ($required in @('name:', 'description:', 'tools:')) {
        if ($frontmatter -notmatch "(?m)^$([regex]::Escape($required))") {
            Add-ValidationError "Copilot agent missing required frontmatter '$required': $(Get-RelativePath $Path)"
        }
    }

    if ($frontmatter -match '(?m)^hooks:') {
        Add-ValidationError "Copilot agent must not use Claude frontmatter hooks: $(Get-RelativePath $Path)"
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

function Test-SharedSkillRuntimeLeakage {
    param([string]$Path)

    $relative = Get-RelativePath -Path $Path
    $text = Get-FileText -Path $Path
    if ($null -eq $text) { return }

    $leakagePatterns = @(
        @{ Pattern = 'Generated with \[?Claude Code'; Message = 'Claude-generated footer' },
        @{ Pattern = 'ExitPlanMode|EnterWorktree|AskUserQuestion'; Message = 'runtime-specific orchestration tool name' },
        @{ Pattern = '(?i)(~[/\\]\.claude|\.claude[/\\]|CLAUDE_PROJECT_DIR)'; Message = 'Claude-specific path or environment variable' },
        @{ Pattern = 'mcp__[A-Za-z0-9_]+__[A-Za-z0-9_]+'; Message = 'Claude-style MCP tool name' }
    )

    foreach ($entry in $leakagePatterns) {
        $matches = [regex]::Matches($text, $entry.Pattern)
        foreach ($match in $matches) {
            $lineNumber = ($text.Substring(0, $match.Index) -split "`n").Count
            Add-ValidationError "Shared skill contains $($entry.Message): $relative line $lineNumber"
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

# Entrypoint invariants.
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
        if ($hasShared) {
            Test-SharedSkillRuntimeLeakage -Path $shared
        }
        if ($hasCopilot) {
            Test-CopilotSkillFrontmatter -Path $copilot
        }
    }
}

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

# Parent README availability coverage and consistency.
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
    Test-MarkerLegend -ReadmePath $readme.Path -Description $readme.Description
}

$rootRows = Get-SupportRows -ReadmePath $rootReadme
$skillRows = Get-SupportRows -ReadmePath $skillsReadme
$agentRows = Get-SupportRows -ReadmePath $agentsReadme
$hookRows = Get-SupportRows -ReadmePath $hooksReadme
$settingsRows = Get-SupportRows -ReadmePath $settingsReadme
$binRows = Get-SupportRows -ReadmePath $binReadme

$skillKeys = @()
if (Test-Path -LiteralPath $skillsDir) {
    $skillKeys = @(Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name | ForEach-Object { $_.Name })
}
Compare-SupportRows -Description 'Skills' -RootRows $rootRows -CategoryRows $skillRows -ExpectedKeys $skillKeys

$agentKeys = @()
if (Test-Path -LiteralPath $agentsDir) {
    $agentKeys = @(Get-ChildItem -LiteralPath $agentsDir -Directory | Sort-Object Name | ForEach-Object { $_.Name })
}
Compare-SupportRows -Description 'Agents' -RootRows $rootRows -CategoryRows $agentRows -ExpectedKeys $agentKeys

$hooksDir = Join-Path $RepoRoot 'hooks'
$hookKeys = @()
if (Test-Path -LiteralPath $hooksDir) {
    $hookKeys = @(Get-ChildItem -LiteralPath $hooksDir -Directory | Sort-Object Name | ForEach-Object { $_.Name })
}
Compare-SupportRows -Description 'Hooks' -RootRows $rootRows -CategoryRows $hookRows -ExpectedKeys $hookKeys

$settingsKeys = @()
foreach ($settingsRoot in @((Join-Path $RepoRoot 'settings\claude'), (Join-Path $RepoRoot 'settings\copilot'))) {
    if (Test-Path -LiteralPath $settingsRoot) {
        $settingsKeys += Get-ChildItem -LiteralPath $settingsRoot -Filter '*.json' -File | ForEach-Object { $_.BaseName }
    }
}
$settingsKeys = @($settingsKeys | Sort-Object -Unique)
Compare-SupportRows -Description 'Settings' -RootRows $rootRows -CategoryRows $settingsRows -ExpectedKeys $settingsKeys

$binKeys = @($binRows.Keys | Sort-Object)
Compare-SupportRows -Description 'Bin' -RootRows $rootRows -CategoryRows $binRows -ExpectedKeys $binKeys

# Settings layout and deterministic arrays.
$settingsTop = Join-Path $RepoRoot 'settings'
if (Test-Path -LiteralPath $settingsTop) {
    Get-ChildItem -LiteralPath $settingsTop -Filter '*.json' -File | ForEach-Object {
        Add-ValidationError "Settings presets must live under settings\claude\ or settings\copilot\, not top-level settings\: $(Get-RelativePath $_.FullName)"
    }
}

foreach ($requiredSettingsDir in @('settings\claude', 'settings\copilot')) {
    $path = Join-Path $RepoRoot $requiredSettingsDir
    if (-not (Test-Path -LiteralPath $path)) {
        Add-ValidationError "Missing settings directory: $requiredSettingsDir"
        continue
    }
    if (-not (Test-Path -LiteralPath (Join-Path $path 'README.md'))) {
        Add-ValidationError "Missing settings directory README: $requiredSettingsDir\README.md"
    }
}

foreach ($settingsRoot in @((Join-Path $RepoRoot 'settings\claude'), (Join-Path $RepoRoot 'settings\copilot')) | Where-Object { Test-Path -LiteralPath $_ }) {
    Get-ChildItem -LiteralPath $settingsRoot -Filter '*.json' -File | Sort-Object Name | ForEach-Object {
        try {
            $json = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
        }
        catch {
            Add-ValidationError "Settings preset is not valid JSON: $(Get-RelativePath $_.FullName)"
            return
        }

        if ($json.permissions) {
            foreach ($property in @('allow', 'deny', 'ask')) {
                $values = @($json.permissions.$property)
                Test-SortedStringArray -Values $values -Path "$(Get-RelativePath $_.FullName): permissions.$property"
            }
        }
    }
}

# Hook preset naming convention.
if (Test-Path -LiteralPath $hooksDir) {
    Get-ChildItem -LiteralPath $hooksDir -Directory | Sort-Object Name | ForEach-Object {
        $hookDir = $_.FullName
        Get-ChildItem -LiteralPath $hookDir -Filter '*.hooks.json' -File | ForEach-Object {
            if ($_.Name -notmatch '^(claude|copilot)\.hooks\.json$') {
                Add-ValidationError "Hook preset must be named <orchestrator>.hooks.json: $(Get-RelativePath $_.FullName)"
            }
            try {
                $null = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
            }
            catch {
                Add-ValidationError "Hook preset is not valid JSON: $(Get-RelativePath $_.FullName)"
            }
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Error ("Validation failed:`n- " + ($errors -join "`n- "))
    exit 1
}

Write-Host 'Validation passed.'
