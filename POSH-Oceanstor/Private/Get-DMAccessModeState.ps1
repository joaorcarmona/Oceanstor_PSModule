function Get-DMAccessModeState {
    <#
    .SYNOPSIS
        Resolves the effective access mode ('ReadWrite' or 'ReadOnly') for this import.

    .DESCRIPTION
        Reads the reserved 'Mode' key from the per-user config JSON (Get-DMFeatureConfigPath) and
        returns the effective mode. This is the single resolver used both by POSH-Oceanstor.psm1
        (to decide whether to hide mutation commands at import time) and by Get-DMAccessMode (to
        report state).

        Resolution rules:
          - Key absent / no config file            -> 'ReadWrite' (Source = 'Default').
          - Key set to 'ReadOnly' or 'ReadWrite'    -> that value (Source = 'UserConfig').

        Robustness (module import must never fail because of config):
          - Missing config file            -> default, no warning.
          - Malformed / unreadable JSON     -> warn, fall back to default.
          - Unrecognized Mode value         -> warn, fall back to default.

        Returns a plain string. Get-DMAccessMode layers the reporting object on top.

    .PARAMETER ConfigPath
        Override the user-config location. Defaults to Get-DMFeatureConfigPath.
    #>
    [CmdletBinding()]
    [OutputType('System.String')]
    param(
        [string]$ConfigPath = (Get-DMFeatureConfigPath)
    )

    $default = 'ReadWrite'

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        return $default
    }

    try {
        $raw = Get-Content -LiteralPath $ConfigPath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) {
            return $default
        }
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Warning "POSH-Oceanstor feature config at '$ConfigPath' could not be read ($($_.Exception.Message)); using access mode '$default'."
        return $default
    }

    $modeProperty = $parsed.PSObject.Properties['Mode']
    if (-not $modeProperty -or [string]::IsNullOrWhiteSpace([string]$modeProperty.Value)) {
        return $default
    }

    switch -Regex ([string]$modeProperty.Value) {
        '^(?i)ReadOnly$'  { return 'ReadOnly' }
        '^(?i)ReadWrite$' { return 'ReadWrite' }
        default {
            Write-Warning "POSH-Oceanstor feature config lists an unknown Mode '$($modeProperty.Value)'; expected 'ReadOnly' or 'ReadWrite'. Using '$default'."
            return $default
        }
    }
}
