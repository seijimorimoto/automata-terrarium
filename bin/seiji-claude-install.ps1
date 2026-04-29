# seiji-claude-install.ps1 — add this repo's bin\ to the user's PowerShell $PROFILE PATH.
#
# Idempotent: a marker block (`# >>> seiji-claude bin >>> ... # <<< seiji-claude bin <<<`)
# is appended to $PROFILE. Re-running detects the marker and does nothing.
#
# Use -DryRun to preview. Use -Uninstall to remove the marker block.
#
# Manual fallback: copy the printed `$env:PATH = ...` line into $PROFILE
# (or wherever you prefer to set PATH) yourself.
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$BinDir    = $ScriptDir

$StartMarker = '# >>> seiji-claude bin >>>'
$EndMarker   = '# <<< seiji-claude bin <<<'
$PathLine    = '$env:PATH = "$env:PATH;' + $BinDir + '"'

# $PROFILE may not exist yet; ensure parent dir exists for write
$profilePath = $PROFILE
$profileDir  = Split-Path -Parent $profilePath

function Test-MarkerPresent {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $content = Get-Content -LiteralPath $Path -Raw
    return ($content -match [regex]::Escape($StartMarker))
}

function Remove-MarkerBlock {
    param([string]$Path)
    $lines = Get-Content -LiteralPath $Path
    $out = New-Object System.Collections.ArrayList
    $skip = $false
    foreach ($line in $lines) {
        if ($line -eq $StartMarker) { $skip = $true; continue }
        if ($line -eq $EndMarker)   { $skip = $false; continue }
        if (-not $skip) { [void]$out.Add($line) }
    }
    Set-Content -LiteralPath $Path -Value $out -Encoding UTF8
}

if ($Uninstall) {
    if (Test-MarkerPresent $profilePath) {
        if ($DryRun) {
            Write-Host "[dry-run] would remove marker block from $profilePath"
        }
        else {
            Remove-MarkerBlock $profilePath
            Write-Host "removed marker block from $profilePath"
        }
    }
    else {
        Write-Host "no marker block found in $profilePath (nothing to uninstall)"
    }
    return
}

if (Test-MarkerPresent $profilePath) {
    Write-Host "$profilePath already configured (marker present); skipping"
    return
}

if ($DryRun) {
    Write-Host "[dry-run] would append the following block to ${profilePath}:"
    Write-Host $StartMarker
    Write-Host $PathLine
    Write-Host $EndMarker
    return
}

if (-not (Test-Path -LiteralPath $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$block = @(
    ''
    $StartMarker
    $PathLine
    $EndMarker
)
Add-Content -LiteralPath $profilePath -Value $block -Encoding UTF8
Write-Host "appended marker block to $profilePath"
Write-Host ""
Write-Host "Open a new PowerShell window, or run:  . `$PROFILE"
Write-Host "to pick up the updated PATH. Then:  seiji-claude-sync"
