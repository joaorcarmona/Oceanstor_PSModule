function Get-DMAccessMode {
    <#
    .SYNOPSIS
        Reports the POSH-Oceanstor access mode (ReadWrite or ReadOnly).

    .DESCRIPTION
        The access mode is a transversal guardrail that cuts across every feature group. In
        'ReadOnly' mode the module hides all array-mutating commands and exports only inspection,
        session, and export commands (verbs Get / Connect / Disconnect / Export) plus a small set
        of local-config control cmdlets (see ExemptCommands). 'ReadWrite' (the default) exports the
        full surface, still subject to the per-feature gating reported by Get-DMFeature.

        'Mode' is the currently-configured value (what a fresh import would use). 'ActiveInSession'
        is the mode captured when this session last imported the module -- the two differ after
        Set-DMAccessMode until you run Import-Module POSH-Oceanstor -Force.

    .EXAMPLE
        Get-DMAccessMode

        Shows the configured mode, the mode active in this session, and the read-only policy.

    .NOTES
        Filename: Get-DMAccessMode.ps1
    #>
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param()

    $configured = Get-DMAccessModeState
    $policy     = Get-DMAccessModePolicy

    # ReadWrite is the built-in default and is never stored, so a configured value of 'ReadOnly'
    # is by definition a user override.
    $source = if ($configured -eq 'ReadOnly') { 'UserConfig' } else { 'Default' }

    $activeInSession = if ($null -ne $script:DMAccessMode) { $script:DMAccessMode } else { $configured }

    [pscustomobject]@{
        Mode            = $configured
        ActiveInSession = $activeInSession
        Source          = $source
        ReadOnlyVerbs   = $policy.ReadOnlyVerbs
        ExemptCommands  = $policy.ExemptCommands
    }
}
