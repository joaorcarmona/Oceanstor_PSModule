function Clear-DMRequestTrace {
    <#
    .SYNOPSIS
        Empties the in-memory OceanStor REST trace buffer.

    .DESCRIPTION
        Discards all trace entries collected by the debug tracer without affecting whether
        tracing is currently enabled. Use between debugging scenarios to start from a clean
        buffer.

    .EXAMPLE
        PS C:\> Clear-DMRequestTrace
        Removes all previously captured trace entries.

    .LINK
        Enable-DMRequestTrace
    .LINK
        Get-DMRequestTrace
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    param()

    # Read via Get-Variable so an unset value does not trip Set-StrictMode.
    $entriesVar = Get-Variable -Name DeviceManagerTraceEntries -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $entriesVar -or $null -eq $entriesVar.Value -or $entriesVar.Value.Count -eq 0) {
        return
    }

    if ($PSCmdlet.ShouldProcess('OceanStor request trace buffer', 'Clear')) {
        $entriesVar.Value.Clear()
    }
}
