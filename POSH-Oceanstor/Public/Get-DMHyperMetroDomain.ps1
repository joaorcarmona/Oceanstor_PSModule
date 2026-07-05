function Get-DMHyperMetroDomain {
    <#
    .SYNOPSIS
        Gets OceanStor SAN HyperMetro domains.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([OceanstorHyperMetroDomain])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "HyperMetroDomain/$encodedId" |
            Select-DMResponseData
        return [OceanstorHyperMetroDomain]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'HyperMetroDomain'
    $domains = foreach ($domainData in @($response)) {
        $domain = [OceanstorHyperMetroDomain]::new($domainData, $session)
        if ($Name -and $domain.Name -notlike $Name) {
            continue
        }
        $domain
    }

    return @($domains)
}
