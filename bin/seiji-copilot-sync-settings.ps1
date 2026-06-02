# seiji-copilot-sync-settings.ps1 — merge settings\copilot\*.json into ~\.copilot\settings.json
# Use -DryRun to print the merged result without writing.
# Use -NoBackup to skip writing the timestamped backup file.
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$NoBackup
)

$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $PSCommandPath
$RepoRoot    = Split-Path -Parent $ScriptDir
$PresetsDir  = Join-Path $RepoRoot 'settings\copilot'
$UserConfDir = Join-Path $HOME '.copilot'
$UserConfig  = Join-Path $UserConfDir 'settings.json'

if (-not (Test-Path -LiteralPath $PresetsDir)) {
    Write-Error "seiji-copilot-sync-settings: presets directory not found: $PresetsDir"
    exit 1
}

function Get-JsonType {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) { return 'string' }
    if ($Value -is [bool]) { return 'bool' }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return 'number' }
    if ($Value -is [System.Array] -or $Value -is [System.Collections.IList]) { return 'array' }
    if ($Value -is [PSCustomObject] -or $Value -is [hashtable]) { return 'object' }
    return 'unknown'
}

function Get-PropertyNames {
    param($Object)
    if ($null -eq $Object) { return @() }
    if ($Object -is [hashtable]) { return @($Object.Keys) }
    return @($Object.PSObject.Properties.Name)
}

function Get-PropertyValue {
    param($Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [hashtable]) {
        if (-not $Object.Contains($Name)) { return $null }
        $v = $Object[$Name]
    }
    else {
        $prop = $Object.PSObject.Properties[$Name]
        if ($null -eq $prop) { return $null }
        $v = $prop.Value
    }
    if ($v -is [System.Array]) { return ,$v }
    return $v
}

function To-Compact-Json {
    param($Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress)
}

function Merge-Json {
    param(
        $User,
        $Preset,
        [string]$PathStr,
        [string]$PresetName,
        [System.Collections.ArrayList]$Warnings
    )

    if ($null -eq $User -and $null -eq $Preset) { return $null }
    if ($null -eq $User)   { return $Preset }
    if ($null -eq $Preset) { return $User }

    $userType   = Get-JsonType $User
    $presetType = Get-JsonType $Preset

    if ($userType -ne $presetType) {
        [void]$Warnings.Add("[$PresetName] type mismatch at '$PathStr' (user=$userType, preset=$presetType); preserving user value")
        return $User
    }

    switch ($userType) {
        'object' {
            $merged = [ordered]@{}
            $allKeys = @(Get-PropertyNames $User) + @(Get-PropertyNames $Preset) | Sort-Object -Unique
            foreach ($key in $allKeys) {
                $u = Get-PropertyValue $User $key
                $p = Get-PropertyValue $Preset $key
                $childPath = if ($PathStr) { "$PathStr.$key" } else { $key }
                $merged[$key] = Merge-Json -User $u -Preset $p -PathStr $childPath -PresetName $PresetName -Warnings $Warnings
            }
            return [PSCustomObject]$merged
        }
        'array' {
            $combined = @() + @($User) + @($Preset)
            $allStrings = $true
            foreach ($item in $combined) {
                if (-not ($item -is [string])) { $allStrings = $false; break }
            }
            if ($allStrings) {
                return @($combined | Sort-Object -Unique)
            }
            $result = New-Object System.Collections.ArrayList
            $seen = @{}
            foreach ($item in $combined) {
                $key = To-Compact-Json $item
                if (-not $seen.ContainsKey($key)) {
                    [void]$result.Add($item)
                    $seen[$key] = $true
                }
            }
            return ,@($result)
        }
        default {
            if ($User -ne $Preset) {
                $userStr = To-Compact-Json $User
                $presetStr = To-Compact-Json $Preset
                [void]$Warnings.Add("[$PresetName] scalar conflict at '$PathStr': user=$userStr, preset would set $presetStr; preserving user value")
            }
            return $User
        }
    }
}

$accumulator = $null
if (Test-Path -LiteralPath $UserConfig) {
    $userText = Get-Content -LiteralPath $UserConfig -Raw
    if ([string]::IsNullOrWhiteSpace($userText)) {
        $accumulator = [PSCustomObject]@{}
    }
    else {
        try {
            $accumulator = $userText | ConvertFrom-Json
        }
        catch {
            Write-Error "seiji-copilot-sync-settings: existing $UserConfig is not valid JSON: $($_.Exception.Message)"
            exit 1
        }
    }
}
else {
    $accumulator = [PSCustomObject]@{}
}

$warnings = New-Object System.Collections.ArrayList
$presetFiles = Get-ChildItem -LiteralPath $PresetsDir -Filter '*.json' -File | Sort-Object Name
if ($presetFiles.Count -eq 0) {
    Write-Host "seiji-copilot-sync-settings: no presets found in $PresetsDir; nothing to merge"
    exit 0
}

foreach ($presetFile in $presetFiles) {
    $presetName = $presetFile.Name
    try {
        $preset = Get-Content -LiteralPath $presetFile.FullName -Raw | ConvertFrom-Json
    }
    catch {
        Write-Error "seiji-copilot-sync-settings: preset $presetName is not valid JSON: $($_.Exception.Message)"
        exit 1
    }
    $accumulator = Merge-Json -User $accumulator -Preset $preset -PathStr '' -PresetName $presetName -Warnings $warnings
}

$mergedJson = $accumulator | ConvertTo-Json -Depth 100
try {
    [void]($mergedJson | ConvertFrom-Json)
}
catch {
    Write-Error "seiji-copilot-sync-settings: merged result is not valid JSON: $($_.Exception.Message)"
    exit 1
}

foreach ($w in $warnings) {
    Write-Warning $w
}

if ($DryRun) {
    Write-Host "[dry-run] would write merged settings to $UserConfig"
    Write-Host "[dry-run] merged content:"
    Write-Host $mergedJson
    exit 0
}

if (-not (Test-Path -LiteralPath $UserConfDir)) {
    New-Item -ItemType Directory -Path $UserConfDir -Force | Out-Null
}

if ((Test-Path -LiteralPath $UserConfig) -and -not $NoBackup) {
    $stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $backup = Join-Path $UserConfDir "settings.backup-$stamp.json"
    Copy-Item -LiteralPath $UserConfig -Destination $backup -Force
    Write-Host "backed up existing settings to $backup"
}

Set-Content -LiteralPath $UserConfig -Value $mergedJson -Encoding UTF8
Write-Host "wrote merged settings to $UserConfig"
