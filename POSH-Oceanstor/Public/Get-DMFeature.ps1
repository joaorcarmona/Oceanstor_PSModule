function Get-DMFeature {
    <#
    .SYNOPSIS
        Lists POSH-Oceanstor command features and their enabled state.

    .DESCRIPTION
        Reports each feature group defined in DMFeatureMap.psd1 together with the effective
        enabled state resolved from the per-user override config. Features that ship disabled
        (HyperMetro, Replication) hide their commands until enabled and the module is re-imported.

        The 'Enabled' column is the currently-configured state (what a fresh import would use).
        'ActiveInSession' is the state captured when this session last imported the module -- it
        differs from 'Enabled' after Enable-DMFeature / Disable-DMFeature until you run
        Import-Module POSH-Oceanstor -Force.

    .PARAMETER Name
        One or more feature names to report. Omit to list every feature.

    .EXAMPLE
        Get-DMFeature

        Lists all features with their enabled state and command counts.

    .EXAMPLE
        Get-DMFeature -Name HyperMetro, Replication

        Shows just the two default-disabled features.
    #>
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param(
        [Parameter(Position = 0)]
        [string[]]$Name
    )

    $state   = Get-DMFeatureState
    $session = $script:DMFeatureState

    if ($Name) {
        $known   = $state.Name
        $unknown = $Name | Where-Object { $_ -notin $known }
        if ($unknown) {
            Write-Error "Unknown feature name(s): $($unknown -join ', '). Valid features: $($known -join ', ')."
            return
        }
        $state = $state | Where-Object { $_.Name -in $Name }
    }

    foreach ($feature in $state) {
        $activeInSession = if ($session) {
            ($session | Where-Object Name -eq $feature.Name).Enabled
        }
        else {
            $feature.Enabled
        }

        [pscustomobject]@{
            Name            = $feature.Name
            Enabled         = $feature.Enabled
            ActiveInSession = $activeInSession
            DefaultEnabled  = $feature.DefaultEnabled
            Source          = $feature.Source
            CommandCount    = $feature.Commands.Count
            Description     = $feature.Description
        }
    }
}
