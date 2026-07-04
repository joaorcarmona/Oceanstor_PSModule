function Get-DMSnmpUsmUser {
    <#
    .SYNOPSIS
        Gets OceanStor SNMP USM user information.
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
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "snmp_usm/$encodedId" |
            Select-DMResponseData
        return [OceanStorSnmpUsmUser]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'snmp_usm'
    return @($response | ForEach-Object { [OceanStorSnmpUsmUser]::new($_, $session) })
}
