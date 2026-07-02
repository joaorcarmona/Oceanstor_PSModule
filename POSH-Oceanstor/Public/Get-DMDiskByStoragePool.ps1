function Get-DMDiskByStoragePool {
    <#
	.SYNOPSIS
		Retrieves the disks that are members of a storage pool.

	.DESCRIPTION
		Fetches every disk and returns those whose poolId matches the target
		storage pool. The OceanStor REST API has no server-side association
		endpoint or filter for disks scoped to a storage pool (unlike
		host/associate for host groups), so filtering happens client-side
		against an exact PoolId match. The target storage pool can be
		identified by an already-resolved object, by name, or by ID.

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
                $pools = @(Get-DMstoragePool -WebSession $session)
                $matchingItems = @($pools | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "StoragePoolName is ambiguous because more than one storage pool is named '$_'."
                }
                throw "Invalid StoragePoolName. Valid values are: $($pools.Name -join ', ')"
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

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $poolId = switch ($PSCmdlet.ParameterSetName) {
        'ByObject' { $StoragePool.Id }
        'ByName' {
            $resolvedPool = @(Get-DMstoragePool -WebSession $session | Where-Object Name -EQ $StoragePoolName)[0]
            if ($null -eq $resolvedPool) { throw "Could not resolve 'StoragePoolName' - the object may have been removed since parameter validation." }
            $resolvedPool.Id
        }
        'ById' { $StoragePoolId }
    }

    $defaultDisplaySet = "Id", "Location", "Health Status", "Disk Usage", "PoolName"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-DMResponseData
    $Storagedisks = New-Object System.Collections.ArrayList

    foreach ($tdisk in $response) {
        $disk = [OceanStorDisks]::new($tdisk, $session)
        [void]$Storagedisks.Add($disk)
    }

    $result = @($Storagedisks | Where-Object poolId -EQ $poolId)

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMDisksByStoragePool -Value Get-DMDiskByStoragePool
