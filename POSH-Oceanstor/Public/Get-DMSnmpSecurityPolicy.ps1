function Get-DMSnmpSecurityPolicy {
    <#
    .SYNOPSIS
        Gets OceanStor SNMP security policy settings.
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

    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'common/snmp_security_policies' |
        Select-DMResponseData
    return [OceanStorSnmpSecurityPolicy]::new($response, $session)
}
