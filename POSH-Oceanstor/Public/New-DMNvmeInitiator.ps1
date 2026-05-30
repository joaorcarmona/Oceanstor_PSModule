function New-DMNvmeInitiator {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidatePattern('^[A-Za-z0-9][\x21-\x7e]{0,222}$')]
        [string]$Nqn,

        [ValidatePattern('^[A-Za-z0-9_.-]{1,31}$')]
        [string]$Name,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{ ID = $Nqn }
    if ($Name) {
        $body.NAME = $Name
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'NVMe_over_RoCE_initiator' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorHostinitiatorNVMe]::new($response.data, $session)
    }
    return $response.error
}
