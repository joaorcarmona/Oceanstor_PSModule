function Get-DMSnmpConfig {
    <#
    .SYNOPSIS
        Gets OceanStor SNMP protocol configuration.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'common/snmp_protocol' |
        Select-DMResponseData
    return [OceanStorSnmpConfig]::new($response, $session)
}
