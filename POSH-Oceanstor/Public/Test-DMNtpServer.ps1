function Test-DMNtpServer {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [string]$Address,

        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    Assert-DMNetworkAddress -Address $Address -ParameterName 'Address'

    $body = @{} + $Property
    $body.CMO_SYS_NTP_CLNT_CONF_SERVER_IP = $Address

    $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'check_ntp_server_address_connective' -BodyData $body
    $response = $response | Assert-DMApiSuccess
    return $response.error
}
