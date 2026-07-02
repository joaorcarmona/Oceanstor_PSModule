function Get-DMlunbyLunGroup {
    <#
	.SYNOPSIS
		Retrieves the LUNs associated with a LUN group.

	.DESCRIPTION
		Queries the LUN group details for ASSOCIATELUNIDLIST and resolves those
		identifiers to the module's LUN objects. The target LUN group can be
		identified by an already-resolved object, by name, or by ID.

	.PARAMETER WebSession
		Optional session to use on REST calls. If omitted, the module's cached $script:CurrentOceanstorSession session is used.

	.PARAMETER LunGroup
		The OceanStorLunGroup object whose member LUNs are requested.

	.PARAMETER LunGroupName
		Name of the LUN group whose member LUNs are requested. The name is validated against existing OceanStor LUN groups and supports tab completion.

	.PARAMETER LunGroupId
		ID of the LUN group whose member LUNs are requested. Not validated before the REST call, same as LunGroup.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession by property name.

	.INPUTS
		OceanStorLunGroup

		You can pipe a LUN group object to LunGroup.

	.OUTPUTS
		OceanstorLun

		Returns the LUN objects associated with the specified LUN group. Returns an empty array when the group has no associated LUNs.

	.EXAMPLE

		PS C:\> $group = (Get-DMlunGroup -WebSession $session)[0]
		PS C:\> Get-DMlunbyLunGroup -WebSession $session -LunGroup $group

	.EXAMPLE

		PS C:\> Get-DMlunbyLunGroup -WebSession $session -LunGroupName 'production-luns'

	.EXAMPLE

		PS C:\> Get-DMlunbyLunGroup -WebSession $session -LunGroupId '3'

	.NOTES
		The command reads the LUN group's ASSOCIATELUNIDLIST value and resolves the identifiers through Get-DMlun.
		If WebSession is omitted, the command uses the module-scoped $script:CurrentOceanstorSession session.
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByObject', ValueFromPipeline = $true, Position = 0, Mandatory = $true)]
        [psobject]$LunGroup,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $true)]
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

        [Parameter(ParameterSetName = 'ById', Position = 0, Mandatory = $true)]
        [string]$LunGroupId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $groupId = switch ($PSCmdlet.ParameterSetName) {
        'ByObject' { $LunGroup.Id }
        'ByName' {
            $resolvedGroup = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
            if ($null -eq $resolvedGroup) { throw "Could not resolve 'LunGroupName' — the object may have been removed since parameter validation." }
            $resolvedGroup.Id
        }
        'ById' { $LunGroupId }
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

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

    $result = @(
        Get-DMlun -WebSession $session |
            Where-Object { $associatedLunIds -contains $_.Id }
    )

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMlunsbyLunGroup -Value Get-DMlunbyLunGroup
