function Get-DMhostbyHostGroup {
    <#
	.SYNOPSIS
		Retrieves the hosts associated with a host group.

	.DESCRIPTION
		Queries host/associate for the hosts associated with a host group
		(ASSOCIATEOBJTYPE=14 identifies a host group), a server-side filtered
		call that returns only that group's member hosts. The target host
		group can be identified by an already-resolved object, by name, or
		by ID.

	.PARAMETER WebSession
		Optional session to use on REST calls. If omitted, the module's cached $script:CurrentOceanstorSession session is used.

	.PARAMETER HostGroup
		The OceanStorHostGroup object whose member hosts are requested.

	.PARAMETER HostGroupName
		Name of the host group whose member hosts are requested. The name is validated against existing OceanStor host groups and supports tab completion.

	.PARAMETER HostGroupId
		ID of the host group whose member hosts are requested. Not validated before the REST call, same as HostGroup.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession by property name.

	.INPUTS
		OceanStorHostGroup

		You can pipe a host group object to HostGroup.

	.OUTPUTS
		OceanStorHost

		Returns the host objects associated with the specified host group. Returns an empty array when the group has no associated hosts.

	.EXAMPLE

		PS C:\> $group = (Get-DMhostGroup -WebSession $session)[0]
		PS C:\> Get-DMhostbyHostGroup -WebSession $session -HostGroup $group

	.EXAMPLE

		PS C:\> Get-DMhostbyHostGroup -WebSession $session -HostGroupName 'production-hosts'

	.EXAMPLE

		PS C:\> Get-DMhostbyHostGroup -WebSession $session -HostGroupId '3'

	.NOTES
		Filename: Get-DMhostbyHostGroup.ps1
		If WebSession is omitted, the command uses the module-scoped $script:CurrentOceanstorSession session.

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByObject', ValueFromPipeline = $true, Position = 0, Mandatory = $true)]
        [psobject]$HostGroup,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $true)]
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

        [Parameter(ParameterSetName = 'ById', Position = 0, Mandatory = $true)]
        [string]$HostGroupId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $groupId = switch ($PSCmdlet.ParameterSetName) {
        'ByObject' { $HostGroup.Id }
        'ByName' {
            $resolvedGroup = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
            if ($null -eq $resolvedGroup) { throw "Could not resolve 'HostGroupName' - the object may have been removed since parameter validation." }
            $resolvedGroup.Id
        }
        'ById' { $HostGroupId }
    }

    $defaultDisplaySet = "Id", "Name", "Health Status", "Operation System", "Parent Name"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host/associate?ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=$groupId" | Select-DMResponseData
    $hosts = New-Object System.Collections.ArrayList

    foreach ($thost in $response) {
        $hostobj = [OceanStorHost]::new($thost, $session)
        [void]$hosts.Add($hostobj)
    }

    $hosts = @(Set-DMHostInitiator -InputObject $hosts -WebSession $session)

    $hosts | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $hosts
}

Set-Alias -Name Get-DMhostsbyHostGroup -Value Get-DMhostbyHostGroup
