function Set-DMFeatureConfig {
    <#
    .SYNOPSIS
        Applies feature enable/disable overrides to the per-user config JSON.

    .DESCRIPTION
        Shared writer behind Enable-DMFeature and Disable-DMFeature. Reads the existing override
        file (tolerantly -- a broken file is replaced, never a hard failure), applies the
        requested changes, then persists only the keys that still differ from their built-in
        default. Redundant keys (value == default) and locked features (Core) are never written,
        so toggling a feature back to its default removes it from the file entirely.

        Creates the config directory on first write. Returns the pruned override hashtable that
        was persisted.

    .PARAMETER Change
        Hashtable of feature name -> desired enabled ([bool]).

    .PARAMETER FeatureMapPath
        Override the feature-map location. Defaults to DMFeatureMap.psd1 beside the module.

    .PARAMETER ConfigPath
        Override the user-config location. Defaults to Get-DMFeatureConfigPath.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType('System.Collections.Hashtable')]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Change,

        [string]$FeatureMapPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\DMFeatureMap.psd1'),

        [string]$ConfigPath = (Get-DMFeatureConfigPath)
    )

    $features = (Import-PowerShellDataFile -LiteralPath $FeatureMapPath).Features

    # Seed from whatever overrides already exist; a corrupt file is discarded, not fatal.
    $overrides = @{}
    if (Test-Path -LiteralPath $ConfigPath) {
        try {
            $raw = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($raw)) {
                $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
                foreach ($property in $parsed.PSObject.Properties) {
                    $overrides[$property.Name] = [bool]$property.Value
                }
            }
        }
        catch {
            Write-Warning "POSH-Oceanstor feature config at '$ConfigPath' was unreadable ($($_.Exception.Message)); rewriting from defaults."
            $overrides = @{}
        }
    }

    foreach ($name in $Change.Keys) {
        $overrides[$name] = [bool]$Change[$name]
    }

    # Persist only meaningful overrides: known, unlocked, and different from the default.
    $pruned = @{}
    foreach ($name in $overrides.Keys) {
        if (-not $features.ContainsKey($name)) { continue }
        if ([bool]$features[$name].Locked) { continue }
        if ([bool]$overrides[$name] -ne [bool]$features[$name].DefaultEnabled) {
            $pruned[$name] = [bool]$overrides[$name]
        }
    }

    $configDir = Split-Path -Path $ConfigPath -Parent
    if ($configDir -and -not (Test-Path -LiteralPath $configDir)) {
        $null = New-Item -Path $configDir -ItemType Directory -Force
    }

    ($pruned | ConvertTo-Json) | Set-Content -LiteralPath $ConfigPath -Encoding utf8
    return $pruned
}
