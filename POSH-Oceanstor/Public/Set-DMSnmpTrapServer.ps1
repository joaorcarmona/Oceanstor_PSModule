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

    $encodedId = [uri]::EscapeDataString($Id)
    if ($PSCmdlet.ShouldProcess($Id, 'Modify SNMP trap server')) {
        # Read-modify-write. The modify interface (PUT snmp_trap_addr/{id}, OceanStor
        # Dorado 6.1.6 REST reference 4.2.1.3.1) marks CMO_TRAP_SERVER_IP and
        # CMO_TRAP_SERVER_PORT as Mandatory body fields alongside ID. A partial body
        # (e.g. ID + PORT only) is rejected or times out on the array (OceanStor API
        # errors 50331651 / 1077949001), so re-read the current server and re-supply
        # the full mandatory field set, overlaying only the fields the caller changed.
        $current = Get-DMSnmpTrapServer -WebSession $session -Id $Id

        $body = @{} + $Property
        $body.ID = $Id
        $body.CMO_TRAP_SERVER_IP = if ($Address) { $Address } else { $current.Address }
        $body.CMO_TRAP_SERVER_PORT = if ($PSBoundParameters.ContainsKey('Port')) { "$Port" } else { $current.Port }

        $effectiveUser = if ($PSBoundParameters.ContainsKey('User')) { $User } else { $current.User }
        if ($effectiveUser) { $body.CMO_TRAP_SERVER_USER = $effectiveUser }

        $effectiveType = if ($PSBoundParameters.ContainsKey('Type')) { $Type } else { $current.Type }
        if ($effectiveType) { $body.CMO_TRAP_SERVER_TYPE = $effectiveType }

        $effectiveVersion = if ($PSBoundParameters.ContainsKey('Version')) { $Version } else { $current.Version }
        if ($effectiveVersion) { $body.CMO_TRAP_VERSION = $effectiveVersion }

        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "snmp_trap_addr/$encodedId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
