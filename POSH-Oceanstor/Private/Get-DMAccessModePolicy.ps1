function Get-DMAccessModePolicy {
    <#
    .SYNOPSIS
        Returns the read-only access-mode policy: allowed verbs and always-exempt commands.

    .DESCRIPTION
        Single source of truth for the transversal ReadOnly guardrail. In ReadOnly mode a command
        is exported only when its verb is in ReadOnlyVerbs OR the command name is in ExemptCommands.

        ReadOnlyVerbs are the inherently non-mutating verbs (inspection, session, and export).
        ExemptCommands are local-config control cmdlets that never touch the array and must stay
        available in ReadOnly mode so the switch can never lock itself out (Set-DMAccessMode above
        all). The Get-* control cmdlets already pass by verb; they are listed here only for clarity.

        Consumed by POSH-Oceanstor.psm1 (to filter exports at import time) and by Get-DMAccessMode
        (to report the effective policy), so the rule is defined exactly once.
    #>
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param()

    [pscustomobject]@{
        ReadOnlyVerbs  = @('Get', 'Connect', 'Disconnect', 'Export')
        ExemptCommands = @(
            'Get-DMAccessMode'
            'Set-DMAccessMode'
            'Get-DMFeature'
            'Enable-DMFeature'
            'Disable-DMFeature'
            'Get-DMRequestTrace'
            'Enable-DMRequestTrace'
            'Disable-DMRequestTrace'
            'Clear-DMRequestTrace'
        )
    }
}
