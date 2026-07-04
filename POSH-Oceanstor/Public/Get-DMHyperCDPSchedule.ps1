function Get-DMHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('ScheduleId')]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateSet('ID', 'NAME', 'RUNNINGSTATUS', 'HEALTHSTATUS')]
        [string]$Filter,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    function ConvertTo-DMScheduleObject {
        param($item, $session)
        return [OceanstorHyperCDPSchedule]::new($item, $session)
    }

    $rawSchedules = switch ($PSCmdlet.ParameterSetName) {
        'ById' {
            $resource = "snapshot_schedule/$Id"
            $query = @('SCHEDULETYPE=1')
            if ($VstoreId) { $query += "vstoreId=$([uri]::EscapeDataString($VstoreId))" }
            $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "$resource`?$($query -join '&')"
            @($response | Select-DMResponseData)
        }
        'ByName' {
            $filterValue = [uri]::EscapeDataString($Name)
            $resource = "snapshot_schedule?SCHEDULETYPE=1&filter=NAME::$filterValue"
            if ($VstoreId) { $resource += "&vstoreId=$([uri]::EscapeDataString($VstoreId))" }
            Invoke-DMPagedRequest -WebSession $session -Resource $resource
        }
        'ByFilter' {
            $filterValue = [uri]::EscapeDataString($Value)
            $resource = "snapshot_schedule?SCHEDULETYPE=1&filter=$Filter`::$filterValue"
            if ($VstoreId) { $resource += "&vstoreId=$([uri]::EscapeDataString($VstoreId))" }
            Invoke-DMPagedRequest -WebSession $session -Resource $resource
        }
        default {
            $resource = 'snapshot_schedule?SCHEDULETYPE=1'
            if ($VstoreId) { $resource += "&vstoreId=$([uri]::EscapeDataString($VstoreId))" }
            Invoke-DMPagedRequest -WebSession $session -Resource $resource
        }
    }

    $result = [System.Collections.ArrayList]::new()
    foreach ($item in @($rawSchedules)) {
        if ($null -ne $item) {
            [void]$result.Add((ConvertTo-DMScheduleObject -item $item -session $session))
        }
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $result = @($result | Where-Object Name -EQ $Name)
    }

    $defaultDisplaySet = 'Id', 'Name', 'Enabled', 'Target Object Type', 'Running Status', 'Health Status'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMHyperCDPSchedules -Value Get-DMHyperCDPSchedule
