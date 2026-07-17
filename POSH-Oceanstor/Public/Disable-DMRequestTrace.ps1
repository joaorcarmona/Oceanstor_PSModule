function Disable-DMRequestTrace {
    <#
    .SYNOPSIS
        Turns off debug tracing of OceanStor REST requests.

    .DESCRIPTION
        Removes the trace hook installed by Enable-DMRequestTrace so that requests are no longer
        captured or printed. Previously collected entries remain available through
        Get-DMRequestTrace unless -Clear is specified.

    .PARAMETER Clear
        Also discards any trace entries collected in memory.

    .EXAMPLE
        PS C:\> Disable-DMRequestTrace
        Stops tracing but keeps the collected entries for later review.

    .EXAMPLE
        PS C:\> Disable-DMRequestTrace -Clear
        Stops tracing and empties the in-memory trace buffer.

    .LINK
        Enable-DMRequestTrace
    #>
    [CmdletBinding()]
    param(
        [switch]$Clear
    )

    $script:DeviceManagerTraceAction = $null
    $script:DeviceManagerTraceConsole = $false
    $script:DeviceManagerTraceLogPath = $null

    if ($Clear) {
        $entriesVar = Get-Variable -Name DeviceManagerTraceEntries -Scope Script -ErrorAction SilentlyContinue
        if ($null -ne $entriesVar -and $null -ne $entriesVar.Value) {
            $entriesVar.Value.Clear()
        }
    }

    Write-Verbose 'OceanStor request tracing disabled.'
}
