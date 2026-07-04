function Get-DMdisk {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks installed. A disk's usage state is
		exclusive -- it cannot be free, a coffer disk, and a member of a storage pool at the same
		time -- so -Free, -Coffer, -StoragePool, -StoragePoolName, and -StoragePoolId are all on one
		mutually-exclusive parameter set (only one, or none, may be supplied per call). -Location is
		independent of usage state and can combine with any of them, or be used alone to search every
		disk by location.

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER Location
		Optional disk location (Enclosure/Slot) to filter by. Supports PowerShell wildcards (*, ?, [...]) via -Match. Can be combined with any usage-state selector below, or used alone against every disk.

	.PARAMETER Free
		Optional switch to return only disks not currently in use (Disk Usage = free). Mutually exclusive with -Coffer and the StoragePool parameters.

	.PARAMETER Coffer
		Optional switch to return only coffer disks. Mutually exclusive with -Free and the StoragePool parameters.

	.PARAMETER StoragePool
		Optional OceanStorStoragePool object whose member disks are requested. Mutually exclusive with -Free and -Coffer.

	.PARAMETER StoragePoolName
		Optional name of the storage pool whose member disks are requested. The name is validated against existing OceanStor storage pools and supports tab completion. Mutually exclusive with -Free and -Coffer.

	.PARAMETER StoragePoolId
		Optional ID of the storage pool whose member disks are requested. Not validated before the REST call, same as -StoragePool. Mutually exclusive with -Free and -Coffer.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.INPUTS
		OceanStorStoragePool

		You can pipe a storage pool object to StoragePool.

	.OUTPUTS
		OceanStorDisks

		Returns installed disk objects. Returns an empty array when no disk matches the requested selector.

	.EXAMPLE

		PS C:\> Get-DMdisk -webSession $session

		OR

		PS C:\> $disks = Get-DMdisk

		OR

		PS C:\> Get-DMdisk -Free

		OR

		PS C:\> Get-DMdisk -Coffer

		OR

		PS C:\> Get-DMdisk -Location DAE000.24

		OR

		PS C:\> Get-DMdisk -StoragePoolName 'performance'

		OR

		PS C:\> Get-DMdisk -StoragePoolId '0' -Location DAE000

	.NOTES
		Filename: Get-DMdisk.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [Cmdletbinding(DefaultParameterSetName = 'All')]
    [OutputType([System.Collections.ArrayList])]
    [OutputType([System.Object[]])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false)]
        [string]$Location,

        [Parameter(ParameterSetName = 'Free', Mandatory = $true)]
        [switch]$Free,

        [Parameter(ParameterSetName = 'Coffer', Mandatory = $true)]
        [switch]$Coffer,

        [Parameter(ParameterSetName = 'ByStoragePoolObject', ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$StoragePool,

        [Parameter(ParameterSetName = 'ByStoragePoolName', Mandatory = $true)]
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

        [Parameter(ParameterSetName = 'ByStoragePoolId', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$StoragePoolId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = "Id", "Location", "Health Status", "Disk Usage", "PoolName"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    $response = Invoke-DMPagedRequest -WebSession $session -Resource "disk"
    $Storagedisks = New-Object System.Collections.ArrayList

    foreach ($tdisk in $response) {
        $disk = [OceanStorDisks]::new($tdisk, $session)
        [void]$Storagedisks.Add($disk)
    }

    $result = @(switch ($PSCmdlet.ParameterSetName) {
            'Free' { $Storagedisks | Where-Object 'Disk Usage' -EQ 'free' }
            'Coffer' { $Storagedisks | Where-Object cofferDisk -EQ $true }
            'ByStoragePoolObject' { $Storagedisks | Where-Object poolId -EQ $StoragePool.Id }
            'ByStoragePoolName' {
                $resolvedPool = @(Get-DMstoragePool -WebSession $session -Name $StoragePoolName)[0]
                if ($null -eq $resolvedPool) { throw "Could not resolve 'StoragePoolName' - the object may have been removed since parameter validation." }
                $Storagedisks | Where-Object poolId -EQ $resolvedPool.Id
            }
            'ByStoragePoolId' { $Storagedisks | Where-Object poolId -EQ $StoragePoolId }
            default { $Storagedisks }
        })

    if ($Location) {
        $result = @($result | Where-Object location -Match $Location)
    }

    $result | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $result
}

Set-Alias -Name Get-DMdisks -Value Get-DMdisk
