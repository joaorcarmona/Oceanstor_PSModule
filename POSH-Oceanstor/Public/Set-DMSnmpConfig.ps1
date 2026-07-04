function Set-DMSnmpConfig {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][hashtable]$Property
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess('SNMP protocol configuration', 'Modify')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'common/snmp_protocol' -BodyData $Property
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
