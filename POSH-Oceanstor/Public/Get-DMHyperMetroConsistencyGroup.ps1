function Get-DMHyperMetroConsistencyGroup {
    <#
    .SYNOPSIS
        Gets OceanStor HyperMetro consistency groups.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([OceanstorHyperMetroConsistencyGroup])]
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
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "HyperMetro_ConsistentGroup/$encodedId" |
            Select-DMResponseData
        return [OceanstorHyperMetroConsistencyGroup]::new($response, $session)
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource 'HyperMetro_ConsistentGroup'
    $groups = foreach ($groupData in @($response)) {
        $group = [OceanstorHyperMetroConsistencyGroup]::new($groupData, $session)
        if ($Name -and $group.Name -notlike $Name) {
            continue
        }
        $group
    }

    return @($groups)
}
