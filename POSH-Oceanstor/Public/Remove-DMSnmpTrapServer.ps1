function Remove-DMSnmpTrapServer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Id
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $encodedId = [uri]::EscapeDataString($Id)
    if ($PSCmdlet.ShouldProcess($Id, 'Remove SNMP trap server')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "snmp_trap_addr/$encodedId"
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
