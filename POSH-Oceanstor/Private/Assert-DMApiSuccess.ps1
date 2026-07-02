function Assert-DMApiSuccess {
    <#
    .SYNOPSIS
        Throws a structured terminating error when an OceanStor REST response reports a non-zero error code.

    .DESCRIPTION
        Pipeline helper for mutation commands (New-DM*, Set-DM*, Remove-DM*, Add-DM*, Enable-DM*,
        Restore-DM*, Restart-DM*, Resize-DM*). Uses the same message format as Select-DMResponseData
        (the equivalent helper for Get-DM* commands) so API failures are reported consistently across
        the module, regardless of whether the caller ends up reading or discarding data.

        On success the response is passed through unchanged so callers can keep chaining `.error`/`.data`
        the way they already do.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$Response
    )
    process {
        if ($null -eq $Response) { return $Response }
        $errorProp = $Response.PSObject.Properties['error']
        if ($null -ne $errorProp -and $errorProp.Value.Code -ne 0) {
            $exception = [System.Exception]::new("OceanStor API error $($errorProp.Value.Code): $($errorProp.Value.description)")
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                $exception, 'OceanStorApiError', [System.Management.Automation.ErrorCategory]::InvalidOperation, $Response
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
        return $Response
    }
}
