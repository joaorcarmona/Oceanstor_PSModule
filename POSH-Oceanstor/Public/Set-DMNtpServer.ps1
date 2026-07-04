function Set-DMNtpServer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [string[]]$Address,

        [switch]$Disabled,

        [uint32]$SyncPeriod,

        [switch]$AuthenticationEnabled,

        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    foreach ($serverAddress in $Address) {
        Assert-DMNetworkAddress -Address $serverAddress -ParameterName 'Address'
    }

    $body = @{} + $Property
    $body.CMO_SYS_NTP_CLNT_CONF_SERVER_IP = ($Address -join ',')
    $body.CMO_SYS_NTP_CLNT_CONF_SWITCH = if ($Disabled.IsPresent) { '0' } else { '1' }
    if ($PSBoundParameters.ContainsKey('SyncPeriod')) { $body.CMO_SYS_NTP_SYNC_PERIOD = "$SyncPeriod" }
    if ($PSBoundParameters.ContainsKey('AuthenticationEnabled')) {
        $body.CMO_SYS_NTP_CLNT_CONF_AUTH_SWITCH = if ($AuthenticationEnabled.IsPresent) { '1' } else { '0' }
    }

    if ($PSCmdlet.ShouldProcess(($Address -join ', '), 'Configure NTP server settings')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'ntp_client_config' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
