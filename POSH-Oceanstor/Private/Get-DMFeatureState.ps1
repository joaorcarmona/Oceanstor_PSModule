function Get-DMFeatureState {
    <#
    .SYNOPSIS
        Resolves the effective enabled/disabled state of every module feature.

    .DESCRIPTION
        Reads the built-in feature map (DMFeatureMap.psd1) and layers the per-user override
        JSON (Get-DMFeatureConfigPath) on top, returning one object per feature describing its
        effective state. This is the single resolver used both by POSH-Oceanstor.psm1 (to decide
        which commands to export at import time) and by Get-DMFeature (to report state).

        Resolution rules:
          - Core is locked: always enabled, any override for it is ignored.
          - A feature named in the config takes the configured value (Source = 'UserConfig').
          - Otherwise the map's DefaultEnabled applies (Source = 'Default').

        Robustness (module import must never fail because of config):
          - Missing config file            -> built-in defaults, no warning.
          - Malformed / unreadable JSON     -> warn, fall back to defaults for all features.
          - Config keys not in the map      -> warn, ignore those keys.

    .PARAMETER FeatureMapPath
        Override the feature-map location. Defaults to DMFeatureMap.psd1 beside the module.

    .PARAMETER ConfigPath
        Override the user-config location. Defaults to Get-DMFeatureConfigPath.
    #>
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param(
        [string]$FeatureMapPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\DMFeatureMap.psd1'),

        [string]$ConfigPath = (Get-DMFeatureConfigPath)
    )

    $features = (Import-PowerShellDataFile -LiteralPath $FeatureMapPath).Features

    # Read the override file. Any read/parse problem degrades to "no overrides" so a broken
    # config can never stop the module from importing.
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
            Write-Warning "POSH-Oceanstor feature config at '$ConfigPath' could not be read ($($_.Exception.Message)); using built-in feature defaults."
            $overrides = @{}
        }
    }

    # Warn about (and ignore) override keys that do not map to a known feature.
    $unknown = $overrides.Keys | Where-Object { $_ -notin $features.Keys }
    if ($unknown) {
        Write-Warning "POSH-Oceanstor feature config lists unknown feature(s): $($unknown -join ', '); ignoring."
    }

    foreach ($name in ($features.Keys | Sort-Object)) {
        $feature        = $features[$name]
        $defaultEnabled = [bool]$feature.DefaultEnabled
        $locked         = [bool]$feature.Locked

        if ($locked) {
            $enabled = $true
            $source  = 'Default'
        }
        elseif ($overrides.ContainsKey($name)) {
            $enabled = $overrides[$name]
            $source  = 'UserConfig'
        }
        else {
            $enabled = $defaultEnabled
            $source  = 'Default'
        }

        [pscustomobject]@{
            Name           = $name
            Enabled        = $enabled
            DefaultEnabled = $defaultEnabled
            Locked         = $locked
            Source         = $source
            Description    = [string]$feature.Description
            Commands       = @($feature.Commands)
        }
    }
}
