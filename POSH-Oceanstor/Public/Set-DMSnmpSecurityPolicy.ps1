function Set-DMSnmpSecurityPolicy {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][hashtable]$Property
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess('SNMP security policy', 'Modify')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'common/snmp_security_policies' -BodyData $Property
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
