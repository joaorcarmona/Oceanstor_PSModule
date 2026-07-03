function Get-DMhostbyHostGroup {
    <#
	.SYNOPSIS
		Deprecated. Retrieves the hosts associated with a host group.

	.DESCRIPTION
		Deprecated - use Get-DMhost -HostGroup / -HostGroupName / -HostGroupId instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

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
		Deprecated: use Get-DMhost -HostGroup / -HostGroupName / -HostGroupId instead.
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

    Write-Warning "Get-DMhostbyHostGroup is deprecated and will be removed in a future release. Use Get-DMhost -HostGroup / -HostGroupName / -HostGroupId instead."

    switch ($PSCmdlet.ParameterSetName) {
        'ByObject' { return Get-DMhost -WebSession $WebSession -HostGroup $HostGroup }
        'ByName' { return Get-DMhost -WebSession $WebSession -HostGroupName $HostGroupName }
        'ById' { return Get-DMhost -WebSession $WebSession -HostGroupId $HostGroupId }
    }
}

Set-Alias -Name Get-DMhostsbyHostGroup -Value Get-DMhostbyHostGroup
