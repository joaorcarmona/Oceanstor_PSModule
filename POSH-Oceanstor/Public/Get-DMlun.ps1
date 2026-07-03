function Get-DMlun {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Luns

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Luns. Exactly one search mode
		may be used per call -- Keyword, Name, Id, WWN, Filter/Value, and
		LunGroup(Name/Id/Object) are mutually exclusive via ParameterSetName. With
		no arguments, returns every LUN.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Keyword
		Optional LUN Name or WWN to search for, positional. When omitted, every LUN is returned. Name is tried first, WWN is a fallback when Name finds nothing. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match.

	.PARAMETER Id
		Optional LUN ID to search for. Returns exactly one LUN, exact match only, no wildcard support.

	.PARAMETER Name
		Optional LUN Name to search for, explicit only (no fallback to WWN, unlike -Keyword). Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. Tab completion offers existing LUN names.

	.PARAMETER WWN
		Optional LUN WWN to search for. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. Tab completion offers existing LUN WWNs.

	.PARAMETER Filter
		Optional property name to filter against, used together with -Value. Validated against the connected array's LUN class properties (OceanstorLunv3 or OceanstorLunv6, depending on array version) before any REST call is made; an unrecognized name throws immediately. Tab completion offers the connected array's LUN property names.

	.PARAMETER Value
		Optional value to match against the property named by -Filter. Supports PowerShell wildcards (*, ?, [...]); without one, the comparison is an exact match. Mandatory when -Filter is supplied.

	.PARAMETER LunGroup
		Optional OceanStorLunGroup object whose member LUNs are requested.

	.PARAMETER LunGroupName
		Optional name of the LUN group whose member LUNs are requested. The name is validated against existing OceanStor LUN groups and supports tab completion.

	.PARAMETER LunGroupId
		Optional ID of the LUN group whose member LUNs are requested. Not validated before the REST call, same as -LunGroup.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession by property name.

	.INPUTS
		OceanStorLunGroup

		You can pipe a LUN group object to LunGroup.

	.OUTPUTS
		OceanstorLunv3
		OceanstorLunv6

		Returns LUN objects. The class depends on the connected OceanStor version. Returns an empty array when no LUN matches the requested selector.

	.EXAMPLE

		PS C:\> Get-DMlun -webSession $session

		OR

		PS C:\> $luns = Get-DMlun

		OR

		PS C:\> Get-DMlun 'finance*'

		OR

		PS C:\> Get-DMlun '658be72100f6793b6bb9512e000000e1'

		OR

		PS C:\> Get-DMlun -Id '1'

		OR

		PS C:\> Get-DMlun -Name 'finance01'

		OR

		PS C:\> Get-DMlun -WWN '6a08cf810075766e1efc050700000005'

		OR

		PS C:\> Get-DMlun -Filter Name -Value 'finance*'

		OR

		PS C:\> Get-DMlun -LunGroupName 'production-luns'

	.NOTES
		Filename: Get-DMlun.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding(DefaultParameterSetName = 'ByKeyword')]
    [OutputType([System.Collections.ArrayList])]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByKeyword', Position = 0, Mandatory = $false)]
        [string]$Keyword,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
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
        [string]$Name,

        [Parameter(ParameterSetName = 'ByWWN', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).WWN | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$WWN,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # A private-function or class-type-literal reference here would not resolve when the
                # real completion engine invokes this scriptblock (confirmed empirically); only calling
                # an already-public command like Get-DMlun works, so property names are read off one
                # live sample object instead of reflecting on the class directly.
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session | Select-Object -First 1).PSObject.Properties.Name |
                    Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Filter,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [Parameter(ParameterSetName = 'ByLunGroupObject', ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$LunGroup,

        [Parameter(ParameterSetName = 'ByLunGroupName', Mandatory = $true)]
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

        [Parameter(ParameterSetName = 'ByLunGroupId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LunGroupId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    function Get-DMlunAllInternal {
        param($session)
        $response = Invoke-DMPagedRequest -WebSession $session -Resource 'lun'
        $storageVersion = $session.version.Substring(0, 2)
        $lunObjectClassName = if ($storageVersion -eq "V6") { "OceanstorLunv6" } else { "OceanstorLunv3" }
        $luns = New-Object System.Collections.ArrayList
        foreach ($tlun in $response) {
            $lun = New-Object -TypeName $lunObjectClassName -ArgumentList @($tlun, $session)
            [void]$luns.Add($lun)
        }
        return $luns
    }

    function Get-DMlunFilteredInternal {
        param($session, $Filter, $Keyword)

        $storageVersion = $session.version.Substring(0, 2)
        $lunObjectClassName = if ($storageVersion -eq "V6") { "OceanstorLunv6" } else { "OceanstorLunv3" }
        $lunObjectClass = if ($storageVersion -eq "V6") { [OceanstorLunv6] } else { [OceanstorLunv3] }

        Assert-DMValidFilterProperty -Type $lunObjectClass -Filter $Filter

        # Map friendly property names to API field names for server-side filtering,
        # used only to narrow the candidate set transferred from the array. The
        # exact requested pattern is always re-verified client-side below, so an
        # imprecise server-side narrowing only costs extra candidates, not correctness.
        $PropertyToApiField = @{
            'Name'              = 'NAME'
            'Id'                = 'ID'
            'WWN'               = 'WWN'
            'Description'       = 'DESCRIPTION'
            'Storage Pool Name' = 'PARENTNAME'
        }

        $apiField = $PropertyToApiField[$Filter]
        $hasWildcard = $Keyword -match '[*?\[\]]'

        if ($apiField -and -not $hasWildcard) {
            # No wildcard: request an exact match server-side (double colon).
            $resource = "lun?filter=$($apiField)::$([uri]::EscapeDataString($Keyword))"
        }
        elseif ($apiField -and $Keyword -match '^\*?([^*?\[\]]+)\*?$') {
            # Wildcard limited to a leading/trailing *: the middle is a literal
            # substring, safe to send as a fuzzy (single colon) narrowing hint.
            $resource = "lun?filter=$($apiField):$([uri]::EscapeDataString($Matches[1]))"
        }
        else {
            # Unmapped field, or a wildcard shape the array's fuzzy filter can't
            # express as one substring (?, a [...] class, or a * in the middle).
            $resource = "lun"
        }

        $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource
        $luns = New-Object System.Collections.ArrayList

        foreach ($tlun in $response) {
            $lun = New-Object -TypeName $lunObjectClassName -ArgumentList @($tlun, $session)
            [void]$luns.Add($lun)
        }

        # Always re-verify against the exact requested pattern client-side, even
        # after a server-side filter. -Like enforces the full wildcard pattern when
        # Keyword has one, and behaves as an exact match when it doesn't.
        return @($luns | Where-Object $Filter -Like $Keyword)
    }

    function Get-DMlunGroupMembersInternal {
        param($session, $groupId)

        $groupResult = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup/$groupId"

        if ($null -eq $groupResult -or $null -eq $groupResult.PSObject.Properties['data']) {
            return @()
        }

        $associatedLunIdList = $groupResult.data.ASSOCIATELUNIDLIST
        if ($null -eq $associatedLunIdList -or [string]::IsNullOrWhiteSpace($associatedLunIdList.ToString())) {
            return @()
        }

        if ($associatedLunIdList -is [string]) {
            try {
                $associatedLunIds = @(ConvertFrom-Json -InputObject $associatedLunIdList -ErrorAction Stop)
            }
            catch {
                # Strip surrounding JSON-array brackets before splitting so that both
                # "[1,2,3]" and "1,2,3" produce the same clean id list.
                $stripped = $associatedLunIdList.Trim().TrimStart('[').TrimEnd(']')
                $associatedLunIds = @($stripped -split ',')
            }
        }
        else {
            $associatedLunIds = @($associatedLunIdList)
        }

        $normalizedLunIds = [System.Collections.Generic.List[string]]::new()
        foreach ($lunId in $associatedLunIds) {
            $normalizedId = $lunId.ToString().Trim().Trim('"')
            if (-not [string]::IsNullOrWhiteSpace($normalizedId)) {
                $normalizedLunIds.Add($normalizedId)
            }
        }

        $associatedLunIds = $normalizedLunIds.ToArray()
        if ($associatedLunIds.Count -eq 0) {
            return @()
        }

        return @(Get-DMlunAllInternal -session $session | Where-Object { $associatedLunIds -contains $_.Id })
    }

    $result = switch ($PSCmdlet.ParameterSetName) {
        'ById' { Get-DMlunFilteredInternal -session $session -Filter 'Id' -Keyword $Id }
        'ByName' { Get-DMlunFilteredInternal -session $session -Filter 'Name' -Keyword $Name }
        'ByWWN' { Get-DMlunFilteredInternal -session $session -Filter 'WWN' -Keyword $WWN }
        'ByFilter' { Get-DMlunFilteredInternal -session $session -Filter $Filter -Keyword $Value }
        'ByLunGroupObject' { Get-DMlunGroupMembersInternal -session $session -groupId $LunGroup.Id }
        'ByLunGroupName' {
            $resolvedGroup = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
            if ($null -eq $resolvedGroup) { throw "Could not resolve 'LunGroupName' - the object may have been removed since parameter validation." }
            Get-DMlunGroupMembersInternal -session $session -groupId $resolvedGroup.Id
        }
        'ByLunGroupId' { Get-DMlunGroupMembersInternal -session $session -groupId $LunGroupId }
        default {
            if ($Keyword) {
                $r = @(Get-DMlunFilteredInternal -session $session -Filter 'Name' -Keyword $Keyword)
                if ($r.Count -eq 0) {
                    $r = @(Get-DMlunFilteredInternal -session $session -Filter 'WWN' -Keyword $Keyword)
                }
                $r
            }
            else {
                Get-DMlunAllInternal -session $session
            }
        }
    }

    $result = @($result)

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

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

Set-Alias -Name Get-DMluns -Value Get-DMlun
