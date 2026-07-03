function Get-DMDiskByStoragePool {
    <#
	.SYNOPSIS
		Deprecated. Retrieves the disks that are members of a storage pool.

	.DESCRIPTION
		Deprecated - use Get-DMdisk -StoragePool / -StoragePoolName / -StoragePoolId instead. This command is a thin wrapper kept for backward compatibility and will be removed in a future release.

	.PARAMETER WebSession
		Optional session to use on REST calls. If omitted, the module's cached $script:CurrentOceanstorSession session is used.

	.PARAMETER StoragePool
		The OceanStorStoragePool object whose member disks are requested.

	.PARAMETER StoragePoolName
		Name of the storage pool whose member disks are requested. The name is validated against existing OceanStor storage pools and supports tab completion.

	.PARAMETER StoragePoolId
		ID of the storage pool whose member disks are requested. Not validated before the REST call, same as StoragePool.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession by property name.

	.INPUTS
		OceanStorStoragePool

		You can pipe a storage pool object to StoragePool.

	.OUTPUTS
		OceanStorDisks

		Returns the disk objects that are members of the specified storage pool. Returns an empty array when the pool has no member disks.

	.EXAMPLE

		PS C:\> $pool = (Get-DMstoragePool -WebSession $session)[0]
		PS C:\> Get-DMDiskByStoragePool -WebSession $session -StoragePool $pool

	.EXAMPLE

		PS C:\> Get-DMDiskByStoragePool -WebSession $session -StoragePoolName 'performance'

	.EXAMPLE

		PS C:\> Get-DMDiskByStoragePool -WebSession $session -StoragePoolId '0'

	.NOTES
		Filename: Get-DMDiskByStoragePool.ps1
		Deprecated: use Get-DMdisk -StoragePool / -StoragePoolName / -StoragePoolId instead.
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
        [psobject]$StoragePool,

        [Parameter(ParameterSetName = 'ByName', Position = 0, Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMstoragePool -WebSession $session -Name $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "StoragePoolName is ambiguous because more than one storage pool is named '$_'."
                }
                throw "Invalid StoragePoolName. Valid values are: $((Get-DMstoragePool -WebSession $session).Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMstoragePool -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$StoragePoolName,

        [Parameter(ParameterSetName = 'ById', Position = 0, Mandatory = $true)]
        [string]$StoragePoolId
    )

    Write-Warning "Get-DMDiskByStoragePool is deprecated and will be removed in a future release. Use Get-DMdisk -StoragePool / -StoragePoolName / -StoragePoolId instead."

    switch ($PSCmdlet.ParameterSetName) {
        'ByObject' { return Get-DMdisk -WebSession $WebSession -StoragePool $StoragePool }
        'ByName' { return Get-DMdisk -WebSession $WebSession -StoragePoolName $StoragePoolName }
        'ById' { return Get-DMdisk -WebSession $WebSession -StoragePoolId $StoragePoolId }
    }
}

Set-Alias -Name Get-DMDisksByStoragePool -Value Get-DMDiskByStoragePool
