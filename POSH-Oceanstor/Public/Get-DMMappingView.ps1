function Get-DMMappingView {
    <#
    .SYNOPSIS
        Retrieves Huawei OceanStor mapping views.

    .DESCRIPTION
        Returns mapping views for the whole system or filtered by host group, LUN group, port group, name, or vStore.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Name
        Optional mapping view name filter.

    .PARAMETER HostGroupName
        Optional host group name used to filter related mapping views.

    .PARAMETER LunGroupName
        Optional LUN group name used to filter related mapping views.

    .PARAMETER PortGroupName
        Optional port group name used to filter related mapping views.

    .PARAMETER VstoreId
        Optional vStore identifier to scope the request.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        Returns one or more OceanStorMappingView objects.

    .EXAMPLE
        PS> Get-DMMappingView -Name 'mv-prod'

    .NOTES
        Filename: Get-DMMappingView.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([System.Collections.ArrayList])]
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
                    $script:CurrentOceanstorSession
                }
                $groups = @(Get-DMhostGroup -WebSession $session)
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
                    $script:CurrentOceanstorSession
                }
                (Get-DMhostGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'LunGroup')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $groups = @(Get-DMlunGroup -WebSession $session)
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
                    $script:CurrentOceanstorSession
                }
                (Get-DMlunGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [Parameter(Mandatory = $true, ParameterSetName = 'PortGroup')]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
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
                    $script:CurrentOceanstorSession
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
        $script:CurrentOceanstorSession
    }
    $resource = 'mappingview'

    switch ($PSCmdlet.ParameterSetName) {
        'HostGroup' {
            $group = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
            if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
            if (-not $group) {
                throw "Host group '$HostGroupName' was not found."
            }
            $resource = "mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=$($group.Id)"
        }
        'LunGroup' {
            $group = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
            if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
            if (-not $group) {
                throw "LUN group '$LunGroupName' was not found."
            }
            $resource = "mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=$($group.Id)"
        }
        'PortGroup' {
            $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
            if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
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

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
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
