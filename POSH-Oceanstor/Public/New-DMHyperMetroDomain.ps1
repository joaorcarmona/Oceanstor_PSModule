function New-DMHyperMetroDomain {
    <#
    .SYNOPSIS
        Creates an OceanStor SAN HyperMetro domain.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([OceanstorHyperMetroDomain])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.-]{0,30}$')]
        [string]$Name,

        [ValidateLength(0, 127)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [object[]]$RemoteDevices,

        [ValidateSet('AA', 'AP')]
        [string]$DomainType,

        [hashtable]$ApiProperties
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{
        NAME          = $Name
        REMOTEDEVICES = @($RemoteDevices)
    }
    Add-DMOptionalBodyValue -Body $body -Key 'DESCRIPTION' -Value $Description -IsPresent $PSBoundParameters.ContainsKey('Description')
    if ($DomainType) {
        $body.DOMAINTYPE = switch ($DomainType) {
            'AA' { 1 }
            'AP' { 2 }
        }
    }
    if ($ApiProperties) {
        foreach ($key in $ApiProperties.Keys) {
            $body[$key] = $ApiProperties[$key]
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create SAN HyperMetro domain')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'HyperMetroDomain' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorHyperMetroDomain]::new($response.data, $session)
        }
        return $response.error
    }
}
