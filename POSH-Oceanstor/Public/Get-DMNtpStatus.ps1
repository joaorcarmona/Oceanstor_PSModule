function Get-DMNtpStatus {
    <#
    .SYNOPSIS
        Gets OceanStor NTP synchronization status.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'ntp_client_config/get_ntp_status' |
        Select-DMResponseData
    return [OceanStorNtpStatus]::new($response, $session)
}
