# seiji-copilot-sync-hooks.ps1 — install Copilot hook scripts and JSON configs to ~\.copilot\hooks\
# Use -DryRun to preview without writing.
[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$RepoRoot  = Split-Path -Parent $ScriptDir
$SrcDir    = Join-Path $RepoRoot 'hooks'
$DstDir    = Join-Path $HOME '.copilot\hooks'

if (-not (Test-Path -LiteralPath $SrcDir)) {
    Write-Error "seiji-copilot-sync-hooks: source not found: $SrcDir"
    exit 1
}

if (-not $DryRun -and -not (Test-Path -LiteralPath $DstDir)) {
    New-Item -ItemType Directory -Path $DstDir -Force | Out-Null
}

function Copy-HookFilesForCopilot {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        if (-not $_.PSIsContainer -and $_.Name -in @('copilot.hooks.json', 'claude.settings.json')) { return }
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $Destination $_.Name) -Recurse -Force
    }
}

$count = 0
Get-ChildItem -LiteralPath $SrcDir -Directory | Sort-Object Name | ForEach-Object {
    $name = $_.Name
    $template = Join-Path $_.FullName 'copilot.hooks.json'
    if (-not (Test-Path -LiteralPath $template)) { return }

    $hookDir = Join-Path $DstDir $name
    $configPath = Join-Path $DstDir "$name.json"

    if ($DryRun) {
        Write-Host "[dry-run] sync Copilot hook '$name': $($_.FullName) -> $hookDir"
        Write-Host "[dry-run] write Copilot hook config: $configPath"
    }
    else {
        Copy-HookFilesForCopilot -Source $_.FullName -Destination $hookDir
        $jsonHookDir = $hookDir.Replace('\', '\\')
        $config = (Get-Content -LiteralPath $template -Raw).Replace('{{COPILOT_HOOK_DIR}}', $jsonHookDir)
        Set-Content -LiteralPath $configPath -Value $config -Encoding UTF8
        Write-Host "synced Copilot hook '$name'"
    }
    $count++
}

if ($DryRun) {
    Write-Host "[dry-run] would sync $count Copilot hook(s) to $DstDir"
}
else {
    Write-Host "synced $count Copilot hook(s) to $DstDir"
}
