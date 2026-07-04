function Get-DMNtpServer {
    <#
    .SYNOPSIS
        Gets OceanStor NTP server configuration.
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

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'ntp_client_config' |
        Select-DMResponseData
    return [OceanStorNtpConfig]::new($response, $session)
}
