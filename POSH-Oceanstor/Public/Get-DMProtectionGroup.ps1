<#
.SYNOPSIS
    Retrieves OceanStor protection groups.

.DESCRIPTION
    Gets protection groups from OceanStor through the API v2 protection group interface.
    With no arguments, returns every protection group. A specific group can be looked up by its
    own Name (wildcard-filtered) or Id. Protection groups can also be found by the LUN or LUN
    group they are associated with, by Name or Id of either, using the OceanStor associated-query
    interface. Piping a LUN (Get-DMLun) or LUN group (Get-DMLunGroup) object does the same thing.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Optional protection group name to search for, positional. Supports PowerShell wildcards (*, ?, [...]). Mutually exclusive with Id, LunName, LunId, LunGroupName, LunGroupId, and InputObject.

.PARAMETER Id
    Optional protection group Id to search for. Returns exactly one protection group, exact match only. Mutually exclusive with Name, LunName, LunId, LunGroupName, LunGroupId, and InputObject.

.PARAMETER LunName
    Name of a LUN whose associated protection groups should be returned. Validated against existing OceanStor LUNs and supports tab completion. Mutually exclusive with Name, Id, LunId, LunGroupName, LunGroupId, and InputObject.

.PARAMETER LunId
    Id of a LUN whose associated protection groups should be returned. Validated against existing OceanStor LUNs, no tab completion. Mutually exclusive with Name, Id, LunName, LunGroupName, LunGroupId, and InputObject.

.PARAMETER LunGroupName
    Name of a LUN group whose associated protection groups should be returned. Validated against existing OceanStor LUN groups and supports tab completion. Mutually exclusive with Name, Id, LunName, LunId, LunGroupId, and InputObject.

.PARAMETER LunGroupId
    Id of a LUN group whose associated protection groups should be returned. Validated against existing OceanStor LUN groups, no tab completion. Mutually exclusive with Name, Id, LunName, LunId, LunGroupName, and InputObject.

.PARAMETER InputObject
    A LUN object (from Get-DMLun) or LUN group object (from Get-DMLunGroup) piped in, whose associated protection groups should be returned.

.INPUTS
    System.Management.Automation.PSCustomObject
    OceanstorLunv3, OceanstorLunv6, OceanStorLunGroup

.OUTPUTS
    OceanstorProtectionGroup

.EXAMPLE
    PS> Get-DMProtectionGroup

    Returns all visible protection groups.

.EXAMPLE
    PS> Get-DMProtectionGroup 'pg-production'

    Returns the protection group named pg-production.

.EXAMPLE
    PS> Get-DMProtectionGroup -Id 5

.EXAMPLE
    PS> Get-DMProtectionGroup -LunName 'production-db'

    Returns protection groups associated with the production-db LUN.

.EXAMPLE
    PS> Get-DMLun 'production-db' | Get-DMProtectionGroup

    Same as above, via the pipeline.

.NOTES
    Filename: Get-DMProtectionGroup.ps1
#>
function Get-DMProtectionGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 1)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByLunName', Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "LunName is ambiguous because more than one LUN is named '$_'." }
                throw 'Invalid LunName.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(ParameterSetName = 'ByLunId', Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMlun -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid LunId.'
            })]
        [string]$LunId,

        [Parameter(ParameterSetName = 'ByLunGroupName', Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMlunGroup -WebSession $session -Name $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "LunGroupName is ambiguous because more than one LUN group is named '$_'." }
                throw 'Invalid LunGroupName.'
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

        [Parameter(ParameterSetName = 'ByLunGroupId', Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMlunGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid LunGroupId.'
            })]
        [string]$LunGroupId,

        [Parameter(ParameterSetName = 'ByObject', ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$InputObject
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    $defaultDisplaySet = 'Id', 'Name', 'Lun Group Name', 'Lun Count', 'Snapshot Group Count', 'vStore Name'
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $associateObjType = $null
    $associateObjId = $null

    switch ($PSCmdlet.ParameterSetName) {
        'ByLunName' {
            $lun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $LunName)[0]
            if ($null -eq $lun) { throw "Could not resolve 'LunName' - the object may have been removed since parameter validation." }
            $associateObjType = 11
            $associateObjId = $lun.Id
        }
        'ByLunId' {
            $associateObjType = 11
            $associateObjId = $LunId
        }
        'ByLunGroupName' {
            $lunGroup = @(Get-DMlunGroup -WebSession $session -Name $LunGroupName)[0]
            if ($null -eq $lunGroup) { throw "Could not resolve 'LunGroupName' - the object may have been removed since parameter validation." }
            $associateObjType = 256
            $associateObjId = $lunGroup.Id
        }
        'ByLunGroupId' {
            $associateObjType = 256
            $associateObjId = $LunGroupId
        }
        'ByObject' {
            $typeName = $InputObject.GetType().Name
            if ($typeName -in 'OceanstorLunv6', 'OceanstorLunv3') {
                $associateObjType = 11
                $associateObjId = $InputObject.Id
            }
            elseif ($typeName -eq 'OceanStorLunGroup') {
                $associateObjType = 256
                $associateObjId = $InputObject.Id
            }
            else {
                throw "Unsupported pipeline object type '$typeName' for Get-DMProtectionGroup. Pipe a LUN (Get-DMLun) or LUN group (Get-DMLunGroup) object."
            }
        }
    }

    $groups = [System.Collections.ArrayList]::new()

    if ($associateObjType) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'GET' `
            -Resource "protectgroup/associate?ASSOCIATEOBJTYPE=$associateObjType&ASSOCIATEOBJID=$associateObjId" -ApiV2 |
            Select-DMResponseData
        foreach ($groupData in @($response)) {
            $group = [OceanstorProtectionGroup]::new($groupData, $session)
            $group | Add-Member MemberSet PSStandardMembers $standardMembers -Force
            [void]$groups.Add($group)
        }
        return $groups
    }

    $resource = 'protectgroup'
    if ($Id) {
        # Double colon requests an exact match; a single colon is a fuzzy substring match on this API.
        $resource += "?filter=protectGroupId::$([uri]::EscapeDataString($Id))"
    }
    elseif ($Name) {
        $hasWildcard = $Name -match '[*?\[\]]'
        if (-not $hasWildcard) {
            $resource += "?filter=protectGroupName::$([uri]::EscapeDataString($Name))"
        }
        elseif ($Name -match '^\*?([^*?\[\]]+)\*?$') {
            $resource += "?filter=protectGroupName:$([uri]::EscapeDataString($Matches[1]))"
        }
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource -ApiV2
    foreach ($groupData in @($response)) {
        $group = [OceanstorProtectionGroup]::new($groupData, $session)
        if ($Id -and $group.Id -ne $Id) {
            continue
        }
        if ($Name -and $group.Name -notlike $Name) {
            continue
        }
        $group | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        [void]$groups.Add($group)
    }

    return $groups
}
