function New-DMMappingView {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor mapping view.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [ValidateLength(0, 255)]
        [string]$Description,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{
        TYPE = 245
        NAME = $Name
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'mappingview' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanStorMappingView]::new($response.data, $session)
    }

    return $response.error
}
