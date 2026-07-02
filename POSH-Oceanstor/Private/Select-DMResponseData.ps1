function Select-DMResponseData {
    # Pipeline helper: throws a descriptive error when the OceanStor API returns a
    # non-zero error code, otherwise returns the .data payload. Replaces the bare
    # '| Select-Object -ExpandProperty data' pattern used in Get-DM* commands so
    # callers see the API error message instead of 'Cannot expand property data'.
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$Response
    )
    process {
        if ($null -eq $Response) { return }
        $errorProp = $Response.PSObject.Properties['error']
        if ($null -ne $errorProp -and $errorProp.Value.Code -ne 0) {
            throw (Get-DMApiErrorMessage -Code $errorProp.Value.Code -Description $errorProp.Value.description)
        }
        return $Response.data
    }
}
