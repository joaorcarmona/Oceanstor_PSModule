function Enable-DMFeature {
    <#
    .SYNOPSIS
        Enables one or more POSH-Oceanstor command features.

    .DESCRIPTION
        Records an enable override in the per-user config so the feature's commands are exported
        on the next import. The change does NOT affect the current session: run
        Import-Module POSH-Oceanstor -Force (or open a new session) for the newly enabled
        commands to appear.

        Only overrides that differ from the built-in default are stored; enabling an
        already-on feature is a no-op that leaves the config unchanged.

    .PARAMETER Name
        One or more feature names to enable. See Get-DMFeature for valid names.

    .EXAMPLE
        Enable-DMFeature -Name HyperMetro
        Import-Module POSH-Oceanstor -Force

        Enables the HyperMetro feature and reloads the module so its commands become available.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name
    )

    $state   = Get-DMFeatureState
    $known   = $state.Name
    $unknown = $Name | Where-Object { $_ -notin $known }
    if ($unknown) {
        throw "Unknown feature name(s): $($unknown -join ', '). Valid features: $($known -join ', ')."
    }

    $change = @{}
    foreach ($featureName in ($Name | Select-Object -Unique)) {
        if ($PSCmdlet.ShouldProcess($featureName, 'Enable feature')) {
            $change[$featureName] = $true
        }
    }

    if ($change.Count -gt 0) {
        $null = Set-DMFeatureConfig -Change $change
        Write-Warning "Feature change saved. Run 'Import-Module POSH-Oceanstor -Force' for it to take effect in this session."
    }

    Get-DMFeatureState | Where-Object { $_.Name -in $Name }
}
