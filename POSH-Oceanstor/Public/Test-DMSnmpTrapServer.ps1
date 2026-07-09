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
    # The send-test interface (PUT snmp_trap_addr/send_test_trapmsg) marks both
    # CMO_TRAP_SERVER_TYPE and CMO_TRAP_VERSION as Mandatory; omitting either makes the
    # array reject the payload with OceanStor API error 50331651. Fall back to the
    # REST-documented create defaults (type 3 = All, version 1 = SNMPv1) when the caller
    # does not override them, so the body is always spec-valid.
    $body.CMO_TRAP_SERVER_TYPE = if ($Type) { $Type } else { '3' }
    $body.CMO_TRAP_VERSION = if ($Version) { $Version } else { '1' }

    $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snmp_trap_addr/send_test_trapmsg' -BodyData $body
    $response = $response | Assert-DMApiSuccess
    return $response.error
}
