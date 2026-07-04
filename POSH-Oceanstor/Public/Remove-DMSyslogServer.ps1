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

    $body = @{} + $Property
    $body.CMO_SYSLOG_SERVER_IP = $Address
    if ($PSCmdlet.ShouldProcess($Address, 'Remove syslog receiver server')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'syslog_removeip' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
