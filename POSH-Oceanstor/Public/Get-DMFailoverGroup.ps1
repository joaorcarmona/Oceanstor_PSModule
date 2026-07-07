function Get-DMFailoverGroup {
    <#
    .SYNOPSIS
        Gets OceanStor failover groups.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Position = 0, ParameterSetName = 'ByName')]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'ByName')]
        [ValidateRange(0, 999999)]
        [int]$RangeStart,

        [Parameter(ParameterSetName = 'All')]
        [Parameter(ParameterSetName = 'ByName')]
        [ValidateRange(1, 10000)]
        [int]$RangeEnd
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $defaultDisplaySet = 'Id', 'Name', 'Failover Group Type', 'Description', 'Service Type'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "failovergroup/$([uri]::EscapeDataString($Id))" | Select-DMResponseData
        $groups = [System.Collections.ArrayList]@([OceanStorFailoverGroup]::new($response, $session))
    }
    else {
        $query = @()
        if ($Name) {
            $query += "filter=NAME::$([uri]::EscapeDataString($Name))"
        }
        if ($PSBoundParameters.ContainsKey('RangeStart') -or $PSBoundParameters.ContainsKey('RangeEnd')) {
            $start = if ($PSBoundParameters.ContainsKey('RangeStart')) { $RangeStart } else { 0 }
            $end = if ($PSBoundParameters.ContainsKey('RangeEnd')) { $RangeEnd } else { 100 }
            $query += "range=[$start-$end]"
        }

        $resource = 'failovergroup'
        if ($query.Count -gt 0) {
            $resource += "?$($query -join '&')"
        }

        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource | Select-DMResponseData
        $groups = New-Object System.Collections.ArrayList
        foreach ($group in @($response)) {
            $groupObject = [OceanStorFailoverGroup]::new($group, $session)
            [void]$groups.Add($groupObject)
        }
    }

    $groups | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $groups
}

Set-Alias -Name Get-DMFailoverGroups -Value Get-DMFailoverGroup
