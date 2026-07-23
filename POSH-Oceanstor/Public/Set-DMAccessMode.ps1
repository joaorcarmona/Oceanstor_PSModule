function Set-DMAccessMode {
    <#
    .SYNOPSIS
        Sets the POSH-Oceanstor access mode (ReadWrite or ReadOnly).

    .DESCRIPTION
        Records the access mode in the per-user config so it takes effect on the next import. The
        change does NOT affect the current session: run Import-Module POSH-Oceanstor -Force (or open
        a new session) for it to apply.

        'ReadOnly' hides every array-mutating command, exporting only inspection, session, and
        export commands (verbs Get / Connect / Disconnect / Export) plus the local-config control
        cmdlets listed by Get-DMAccessMode. This is a safety brake for connecting to production
        arrays where only inspection and export are intended. 'ReadWrite' (the default) restores the
        full command surface.

        Because 'ReadWrite' is the built-in default it is never stored -- selecting it removes the
        override. Feature overrides in the same config file are preserved.

    .PARAMETER Mode
        The access mode to configure: 'ReadOnly' or 'ReadWrite'.

    .EXAMPLE
        Set-DMAccessMode -Mode ReadOnly
        Import-Module POSH-Oceanstor -Force

        Puts the module in read-only mode and reloads it so mutation commands disappear.

    .EXAMPLE
        Set-DMAccessMode -Mode ReadWrite
        Import-Module POSH-Oceanstor -Force

        Restores the full command surface.

    .NOTES
        Filename: Set-DMAccessMode.ps1
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('ReadOnly', 'ReadWrite')]
        [string]$Mode
    )

    if ($PSCmdlet.ShouldProcess('POSH-Oceanstor', "Set access mode to $Mode")) {
        $null = Set-DMAccessModeConfig -Mode $Mode
        Write-Warning "Access mode saved. Run 'Import-Module POSH-Oceanstor -Force' for it to take effect in this session."
    }

    Get-DMAccessMode
}
