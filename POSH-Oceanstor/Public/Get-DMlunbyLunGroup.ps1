function Get-DMlunbyLunGroup {
    <#
	.SYNOPSIS
		Retrieves the LUNs associated with a LUN group.

	.DESCRIPTION
		Queries the LUN group details for ASSOCIATELUNIDLIST and resolves those
		identifiers to the module's LUN objects.

	.PARAMETER WebSession
		Optional session to use on REST calls. If omitted, the module's cached $script:CurrentOceanstorSession session is used.

	.PARAMETER LunGroup
		The OceanStorLunGroup object whose member LUNs are requested.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.INPUTS
		OceanStorLunGroup

		You can pipe a LUN group object to LunGroup.

	.OUTPUTS
		OceanstorLun

		Returns the LUN objects associated with the specified LUN group. Returns an empty array when the group has no associated LUNs.

	.EXAMPLE

		PS C:\> $group = (Get-DMlunGroup -WebSession $session)[0]
		PS C:\> Get-DMlunbyLunGroup -WebSession $session -LunGroup $group

	.NOTES
		The command reads the LUN group's ASSOCIATELUNIDLIST value and resolves the identifiers through Get-DMlun.
		If WebSession is omitted, the command uses the module-scoped $script:CurrentOceanstorSession session.
	#>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, Position = 1, Mandatory = $true)]
        [psobject]$LunGroup
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $groupResult = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup/$($LunGroup.Id)"

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
