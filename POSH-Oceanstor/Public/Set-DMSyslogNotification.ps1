function Set-DMSyslogNotification {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][hashtable]$Property
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess('Syslog notification settings', 'Modify')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'syslog' -BodyData $Property
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
