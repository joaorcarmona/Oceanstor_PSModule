function Get-DMFileHyperMetroDomain {
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType('OceanstorFileHyperMetroDomain')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(ParameterSetName = 'ByName', Position = 0)][string]$Name,
        [Parameter(ParameterSetName = 'ById', Mandatory = $true)][string]$Id
    )
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "FsHyperMetroDomain/$encodedId" |
            Select-DMResponseData
        return [OceanstorFileHyperMetroDomain]::new($response, $session)
    }
    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'FsHyperMetroDomain'
    $domains = foreach ($domainData in @($response)) {
        $domain = [OceanstorFileHyperMetroDomain]::new($domainData, $session)
        if ($Name -and $domain.Name -notlike $Name) { continue }
        $domain
    }
    return @($domains)
}
