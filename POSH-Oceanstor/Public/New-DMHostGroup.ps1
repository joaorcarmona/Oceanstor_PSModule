function New-DMHostGroup {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor host group.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(Position = 2)]
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
        TYPE = 14
        NAME = $Name
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'hostgroup' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanStorHostGroup]::new($response.data, $session)
    }

    return $response.error
}
