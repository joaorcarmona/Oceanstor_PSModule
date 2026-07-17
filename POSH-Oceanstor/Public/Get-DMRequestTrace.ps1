function Get-DMRequestTrace {
    <#
    .SYNOPSIS
        Returns the OceanStor REST request/response entries captured by the debug tracer.

    .DESCRIPTION
        Emits the trace entries collected since Enable-DMRequestTrace was called (or since the
        last -Clear). Each entry is a PSCustomObject with Vendor, Hostname, Version, Method,
        Uri, StatusCode, Request, Response and Exception; depth-2 entries also carry RawJsonBody,
        RawResponse and Headers. Pipe to Format-List for readability or ConvertTo-Json to export.

    .PARAMETER Last
        Return only the most recent N entries.

    .PARAMETER Clear
        Discard the in-memory buffer after returning the entries.

    .EXAMPLE
        PS C:\> Get-DMRequestTrace | Format-List
        Shows every captured request/response.

    .EXAMPLE
        PS C:\> Get-DMRequestTrace -Last 5
        Shows the five most recent requests.

    .EXAMPLE
        PS C:\> Get-DMRequestTrace | ConvertTo-Json -Depth 12 | Set-Content trace.json
        Exports the full trace for offline analysis.

    .LINK
        Enable-DMRequestTrace
    .LINK
        Clear-DMRequestTrace
    #>
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSCustomObject')]
    param(
        [ValidateRange(1, [int]::MaxValue)]
        [int]$Last,

        [switch]$Clear
    )

    # Read via Get-Variable so an unset value does not trip Set-StrictMode.
    $entriesVar = Get-Variable -Name DeviceManagerTraceEntries -Scope Script -ErrorAction SilentlyContinue
    if ($null -eq $entriesVar -or $null -eq $entriesVar.Value -or $entriesVar.Value.Count -eq 0) {
        return
    }

    $buffer = $entriesVar.Value
    $entries = $buffer.ToArray()
    if ($PSBoundParameters.ContainsKey('Last') -and $Last -lt $entries.Count) {
        $entries = $entries[($entries.Count - $Last)..($entries.Count - 1)]
    }

    $entries

    if ($Clear) {
        $buffer.Clear()
    }
}
