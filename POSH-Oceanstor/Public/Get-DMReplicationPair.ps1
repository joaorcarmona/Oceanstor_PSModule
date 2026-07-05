function Get-DMReplicationPair {
    <#
    .SYNOPSIS
        Gets OceanStor remote replication pairs.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([OceanstorReplicationPair])]
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
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "REPLICATIONPAIR/$encodedId" |
            Select-DMResponseData
        return [OceanstorReplicationPair]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'REPLICATIONPAIR'
    $pairs = foreach ($pairData in @($response)) {
        $pair = [OceanstorReplicationPair]::new($pairData, $session)
        if ($Name -and $pair.{Local Resource Name} -notlike $Name -and $pair.{Remote Resource Name} -notlike $Name -and $pair.Id -notlike $Name) {
            continue
        }
        $pair
    }

    return @($pairs)
}
