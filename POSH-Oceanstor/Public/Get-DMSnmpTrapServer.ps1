function Get-DMSnmpTrapServer {
    <#
    .SYNOPSIS
        Gets OceanStor SNMP trap server settings.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([pscustomobject[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [string]$Id
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "snmp_trap_addr/$encodedId" |
            Select-DMResponseData
        return [OceanStorSnmpTrapServer]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'snmp_trap_addr'
    return @($response | ForEach-Object { [OceanStorSnmpTrapServer]::new($_, $session) })
}
