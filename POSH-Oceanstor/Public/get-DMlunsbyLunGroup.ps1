function get-DMlunsbyLunGroup {
    <#
	.SYNOPSIS
		Retrieves the LUNs associated with a LUN group.

	.DESCRIPTION
		Queries the LUN group details for ASSOCIATELUNIDLIST and resolves those
		identifiers to the module's LUN objects.

	.PARAMETER WebSession
		Optional session to use on REST calls. If omitted, deviceManager is used.

	.PARAMETER LunGroup
		The OceanStorLunGroup object whose member LUNs are requested.

	.EXAMPLE

		PS C:\> $group = (get-DMlunGroups -WebSession $session)[0]
		PS C:\> get-DMlunsbyLunGroup -WebSession $session -LunGroup $group
	#>
    [CmdletBinding()]
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
        $session = $deviceManager
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Lun Size", "WWN"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $groupResult = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup/$($LunGroup.Id)"

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
            $associatedLunIds = @($associatedLunIdList -split ',')
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
        get-DMluns -WebSession $session |
            Where-Object { $associatedLunIds -contains $_.Id }
    )

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}
