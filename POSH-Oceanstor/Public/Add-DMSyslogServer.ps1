function Add-DMSyslogServer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Address,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    Assert-DMNetworkAddress -Address $Address -ParameterName 'Address'

    # syslog_addip only accepts a server-IP field (verified against the 6.1.6 REST reference);
    # there is no per-server severity/port/protocol setting, so none is exposed here.
    $body = @{} + $Property
    $body.CMO_SYSLOG_SERVER_IP = $Address
    if ($PSCmdlet.ShouldProcess($Address, 'Add syslog receiver server')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'syslog_addip' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
