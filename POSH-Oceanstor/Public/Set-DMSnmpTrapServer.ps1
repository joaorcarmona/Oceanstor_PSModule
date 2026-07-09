function Set-DMSnmpTrapServer {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Address,
        [uint32]$Port,
        [string]$User,
        [string]$Type,
        [string]$Version,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($Address) {
        Assert-DMNetworkAddress -Address $Address -ParameterName 'Address'
    }

    $body = @{} + $Property
    # The modify interface (PUT snmp_trap_addr/{id}) requires the object ID in the
    # request body as well as in the URL path; omitting it makes the array reject the
    # payload with OceanStor API error 50331651 ("The entered parameter is incorrect").
    $body.ID = $Id
    if ($Address) { $body.CMO_TRAP_SERVER_IP = $Address }
    if ($PSBoundParameters.ContainsKey('Port')) { $body.CMO_TRAP_SERVER_PORT = "$Port" }
    if ($User) { $body.CMO_TRAP_SERVER_USER = $User }
    if ($Type) { $body.CMO_TRAP_SERVER_TYPE = $Type }
    if ($Version) { $body.CMO_TRAP_VERSION = $Version }

    $encodedId = [uri]::EscapeDataString($Id)
    if ($PSCmdlet.ShouldProcess($Id, 'Modify SNMP trap server')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "snmp_trap_addr/$encodedId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
