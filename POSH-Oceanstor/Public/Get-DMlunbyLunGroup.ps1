function Get-DMlunbyLunGroup {
    <#
	.SYNOPSIS
		Deprecated. Retrieves the LUNs associated with a LUN group.

	.DESCRIPTION
		Deprecated - use Get-DMlun -LunGroup / -LunGroupName / -LunGroupId instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

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
		Filename: Get-DMlunbyLunGroup.ps1
		Deprecated: use Get-DMlun -LunGroup / -LunGroupName / -LunGroupId instead.
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

    Write-Warning "Get-DMlunbyLunGroup is deprecated and will be removed in a future release. Use Get-DMlun -LunGroup / -LunGroupName / -LunGroupId instead."

    switch ($PSCmdlet.ParameterSetName) {
        'ByObject' { return Get-DMlun -WebSession $WebSession -LunGroup $LunGroup }
        'ByName' { return Get-DMlun -WebSession $WebSession -LunGroupName $LunGroupName }
        'ById' { return Get-DMlun -WebSession $WebSession -LunGroupId $LunGroupId }
    }
}

Set-Alias -Name Get-DMlunsbyLunGroup -Value Get-DMlunbyLunGroup
