function Test-DMSnmpTrapServer {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Address,
        [Parameter(Mandatory = $true)][uint32]$Port,
        [string]$User,
        [string]$Type,
        [string]$Version,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    Assert-DMNetworkAddress -Address $Address -ParameterName 'Address'

    $body = @{} + $Property
    $body.CMO_TRAP_SERVER_IP = $Address
    $body.CMO_TRAP_SERVER_PORT = "$Port"
    if ($User) { $body.CMO_TRAP_SERVER_USER = $User }
    if ($Type) { $body.CMO_TRAP_SERVER_TYPE = $Type }
    if ($Version) { $body.CMO_TRAP_VERSION = $Version }

    $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snmp_trap_addr/send_test_trapmsg' -BodyData $body
    $response = $response | Assert-DMApiSuccess
    return $response.error
}
