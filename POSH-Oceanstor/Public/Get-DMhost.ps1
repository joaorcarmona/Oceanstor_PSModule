function Get-DMhost {
    <#
.SYNOPSIS
    To Get Huawei Oceanstor Storage configured Hosts

.DESCRIPTION
    Function to request Huawei Oceanstor Storage configured Hosts. Consolidates
    the functionality previously spread across Get-DMhostbyFilter, Get-DMhostbyName,
    Get-DMhostbyId, and Get-DMhostbyHostGroup (all now thin deprecated wrappers
    around this command).

.PARAMETER webSession
    Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

.PARAMETER Name
    Optional host name to search for, positional. When omitted, every host is returned. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

.PARAMETER Id
    Optional host ID to search for. Mutually exclusive with Name (enforced by parameter set). Returns exactly one host, exact match only, no wildcard support.

.PARAMETER Filter
    Property name to filter against (mutually exclusive with Name/Id/HostGroup*). Validated against OceanStorHost's actual properties before any REST call is made; an unrecognized name throws immediately. Requires Value.

.PARAMETER Value
    Value to match against the property chosen with Filter. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

.PARAMETER HostGroup
    The OceanStorHostGroup object whose member hosts are requested (mutually exclusive with Name/Id/Filter).

.PARAMETER HostGroupName
    Name of the host group whose member hosts are requested (mutually exclusive with Name/Id/Filter). The name is validated against existing OceanStor host groups and supports tab completion.

.PARAMETER HostGroupId
    ID of the host group whose member hosts are requested (mutually exclusive with Name/Id/Filter). Not validated before the REST call, same as HostGroup.

.PARAMETER VstoreId
    Optional vstore ID to scope the unfiltered host list to. Only applies when no Name/Id/Filter/HostGroup* selector is supplied.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession.

.INPUTS
    OceanStorHostGroup

    You can pipe a host group object to HostGroup.

.OUTPUTS
    OceanStorHost

    Returns host objects.

.EXAMPLE

    PS C:\> Get-DMhost -webSession $session

    OR

    PS C:\> $hosts = Get-DMhost

    OR

    PS C:\> Get-DMhost 'esx01'

    OR

    PS C:\> Get-DMhost -Id '1'

    OR

    PS C:\> Get-DMhost -Filter Name -Value 'esx*'

    OR

    PS C:\> Get-DMhost -HostGroupName 'production-hosts'

.NOTES
    Filename: Get-DMhost.ps1

.LINK
#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding(DefaultParameterSetName = 'ByName')]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $false)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhost -WebSession $session | Select-Object -First 1).PSObject.Properties.Name |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Filter,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [Parameter(ParameterSetName = 'ByHostGroupObject', ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$HostGroup,

        [Parameter(ParameterSetName = 'ByHostGroupName', Mandatory = $true)]
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

        [Parameter(ParameterSetName = 'ByHostGroupId', Mandatory = $true)]
        [string]$HostGroupId,

        [string]$VstoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    function Get-DMhostAllInternal {
        param($session, $VstoreId)

        $resource = 'host'
        if ($VstoreId) {
            $resource += "?vstoreId=$VstoreId"
        }
        $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
        $hosts = New-Object System.Collections.ArrayList

        foreach ($thost in $response) {
            $hostobj = [OceanStorHost]::new($thost, $session)
            [void]$hosts.Add($hostobj)
        }

        return @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)
    }

    function Get-DMhostFilteredInternal {
        param($session, $Filter, $Keyword)

        Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter $Filter

        $PropertyToApiField = @{
            'Id'   = 'ID'
            'Name' = 'NAME'
        }

        $apiField = $PropertyToApiField[$Filter]
        $hasWildcard = $Keyword -match '[*?\[\]]'

        if ($apiField -and -not $hasWildcard) {
            $resource = "host?filter=$($apiField)::$([uri]::EscapeDataString($Keyword))"
        }
        elseif ($apiField -and $Keyword -match '^\*?([^*?\[\]]+)\*?$') {
            $resource = "host?filter=$($apiField):$([uri]::EscapeDataString($Matches[1]))"
        }
        else {
            $resource = "host"
        }

        $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
        $hosts = New-Object System.Collections.ArrayList

        foreach ($thost in $response) {
            $hostobj = [OceanStorHost]::new($thost, $session)
            [void]$hosts.Add($hostobj)
        }

        $hosts = @($hosts | Where-Object $Filter -Like $Keyword)

        return @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)
    }

    function Get-DMhostGroupMembersInternal {
        param($session, $groupId)

        $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=$groupId" | Select-DMResponseData
        $hosts = New-Object System.Collections.ArrayList

        foreach ($thost in $response) {
            $hostobj = [OceanStorHost]::new($thost, $session)
            [void]$hosts.Add($hostobj)
        }

        return @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)
    }

    $result = switch ($PSCmdlet.ParameterSetName) {
        'ById' { Get-DMhostFilteredInternal -session $session -Filter 'Id' -Keyword $Id }
        'ByFilter' { Get-DMhostFilteredInternal -session $session -Filter $Filter -Keyword $Value }
        'ByHostGroupObject' { Get-DMhostGroupMembersInternal -session $session -groupId $HostGroup.Id }
        'ByHostGroupName' {
            $resolvedGroup = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
            if ($null -eq $resolvedGroup) { throw "Could not resolve 'HostGroupName' - the object may have been removed since parameter validation." }
            Get-DMhostGroupMembersInternal -session $session -groupId $resolvedGroup.Id
        }
        'ByHostGroupId' { Get-DMhostGroupMembersInternal -session $session -groupId $HostGroupId }
        default {
            if ($Name) {
                Get-DMhostFilteredInternal -session $session -Filter 'Name' -Keyword $Name
            }
            else {
                Get-DMhostAllInternal -session $session -VstoreId $VstoreId
            }
        }
    }

    $result = @($result)

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

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

Set-Alias -Name Get-DMhosts -Value Get-DMhost
