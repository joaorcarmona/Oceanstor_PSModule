function Set-DMSnmpCommunity {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [hashtable]$Property = @{},
        [object]$Community,
        [string]$CommunityPropertyName = 'SNMP_COMMUNITY'
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    if ($PSBoundParameters.ContainsKey('Community')) {
        $body[$CommunityPropertyName] = ConvertFrom-DMSensitiveValue -Value $Community
    }
    if ($body.Count -eq 0) {
        throw 'Specify -Community or at least one value in -Property.'
    }

    if ($PSCmdlet.ShouldProcess('SNMP community information', 'Modify')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'SNMP_COMMUNITY' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
