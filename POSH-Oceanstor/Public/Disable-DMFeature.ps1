function Disable-DMFeature {
    <#
    .SYNOPSIS
        Disables one or more POSH-Oceanstor command features.

    .DESCRIPTION
        Records a disable override in the per-user config so the feature's commands are no longer
        exported on the next import. The change does NOT affect the current session: run
        Import-Module POSH-Oceanstor -Force (or open a new session) for the commands to disappear.

        Only overrides that differ from the built-in default are stored; disabling a feature that
        is already off by default removes the redundant key instead of writing it. The Core
        feature is locked and cannot be disabled.

    .PARAMETER Name
        One or more feature names to disable. See Get-DMFeature for valid names.

    .EXAMPLE
        Disable-DMFeature -Name HyperMetro
        Import-Module POSH-Oceanstor -Force

        Disables the HyperMetro feature and reloads the module so its commands are hidden.
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

    $locked = $state | Where-Object { $_.Locked -and $_.Name -in $Name }
    if ($locked) {
        throw "Feature(s) $($locked.Name -join ', ') are locked and cannot be disabled."
    }

    $change = @{}
    foreach ($featureName in ($Name | Select-Object -Unique)) {
        if ($PSCmdlet.ShouldProcess($featureName, 'Disable feature')) {
            $change[$featureName] = $false
        }
    }

    if ($change.Count -gt 0) {
        $null = Set-DMFeatureConfig -Change $change
        Write-Warning "Feature change saved. Run 'Import-Module POSH-Oceanstor -Force' for it to take effect in this session."
    }

    Get-DMFeatureState | Where-Object { $_.Name -in $Name }
}
