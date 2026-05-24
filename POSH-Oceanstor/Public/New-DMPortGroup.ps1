function New-DMPortGroup {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor port group.
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
        [ValidateLength(0, 63)]
        [string]$Description
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $body = @{ NAME = $Name }
    if ($PSBoundParameters.ContainsKey('Description')) { $body.DESCRIPTION = $Description }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'portgroup' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorPortGroup]::new($response.data, $session)
    }

    return $response.error
}
