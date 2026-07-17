function Remove-DMSyslogServer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Address,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    Assert-DMNetworkAddress -Address $Address -ParameterName 'Address'

    # syslog_removeip identifies the receiver by the same mandatory field name as
    # the add interface (REST reference section 4.2.2.2.1): CMO_ALARM_SYSLOG_SERVER_IP.
    $body = @{} + $Property
    $body.CMO_ALARM_SYSLOG_SERVER_IP = $Address
    if ($PSCmdlet.ShouldProcess($Address, 'Remove syslog receiver server')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'syslog_removeip' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
