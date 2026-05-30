function Get-DMMappingView {
    <#
    .SYNOPSIS
        Retrieves Huawei OceanStor mapping views, optionally associated with a group.
    #>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 1)]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'HostGroup')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMhostGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$_'."
                }
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhostGroups -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroup')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMlunGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$_'."
                }
                throw "Invalid LunGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMlunGroups -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'PortGroup')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMPortGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "PortGroupName is ambiguous because more than one port group is named '$_'."
                }
                throw "Invalid PortGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMPortGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$PortGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $resource = 'mappingview'

    switch ($PSCmdlet.ParameterSetName) {
        'HostGroup' {
            $group = @(Get-DMhostGroups -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
            if (-not $group) {
                throw "Host group '$HostGroupName' was not found."
            }
            $resource = "mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=$($group.Id)"
        }
        'LunGroup' {
            $group = @(Get-DMlunGroups -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
            if (-not $group) {
                throw "LUN group '$LunGroupName' was not found."
            }
            $resource = "mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=$($group.Id)"
        }
        'PortGroup' {
            $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
            if (-not $group) {
                throw "Port group '$PortGroupName' was not found."
            }
            $resource = "mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=257&ASSOCIATEOBJID=$($group.Id)"
        }
    }

    if ($VstoreId) {
        $separator = if ($resource.Contains('?')) {
            '&'
        }
        else {
            '?'
        }
        $resource += "${separator}vstoreId=$VstoreId"
    }

    $queryResult = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $resource
    $response = @()
    if ($null -ne $queryResult -and $null -ne $queryResult.PSObject.Properties['data']) {
        $response = @($queryResult.data)
    }
    $defaultDisplaySet = 'Id', 'Name', 'Host Group Id', 'LUN Group Id', 'Port Group Id', 'vStore Name'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $views = [System.Collections.ArrayList]::new()

    foreach ($viewData in @($response)) {
        $view = [OceanStorMappingView]::new($viewData, $session)
        if (-not $Name -or $view.Name -eq $Name) {
            $view | Add-Member MemberSet PSStandardMembers $standardMembers -Force
            [void]$views.Add($view)
        }
    }

    return $views
}
