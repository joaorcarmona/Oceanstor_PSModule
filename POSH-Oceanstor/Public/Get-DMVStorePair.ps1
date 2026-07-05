function Get-DMVStorePair {
    [CmdletBinding(DefaultParameterSetName = 'ByFilter')]
    [OutputType([OceanstorVStorePair])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByFilter')]
        [ValidateSet('HyperMetro', 'RemoteReplication')]
        [string]$ReplicationType,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $encodedId = [uri]::EscapeDataString($Id)
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "vstore_pair/$encodedId" |
            Select-DMResponseData
        return [OceanstorVStorePair]::new($response, $session)
    }

    $resource = 'vstore_pair'
    if ($ReplicationType) {
        $repTypeCode = if ($ReplicationType -eq 'HyperMetro') { '1' } else { '2' }
        $resource += "?filter=REPTYPE::$repTypeCode"
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
    return @($response | ForEach-Object { [OceanstorVStorePair]::new($_, $session) })
}
