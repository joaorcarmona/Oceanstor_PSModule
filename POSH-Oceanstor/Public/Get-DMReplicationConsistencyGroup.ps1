function Get-DMReplicationConsistencyGroup {
    <#
    .SYNOPSIS
        Gets OceanStor remote replication consistency groups.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType('OceanstorReplicationConsistencyGroup')]
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
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "CONSISTENTGROUP/$encodedId" |
            Select-DMResponseData
        return [OceanstorReplicationConsistencyGroup]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'CONSISTENTGROUP'
    $groups = foreach ($groupData in @($response)) {
        $group = [OceanstorReplicationConsistencyGroup]::new($groupData, $session)
        if ($Name -and $group.Name -notlike $Name) {
            continue
        }
        $group
    }

    return @($groups)
}
