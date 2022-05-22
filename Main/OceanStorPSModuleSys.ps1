function get-DMdisks{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks installed

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage disks installed

	.EXAMPLE

		PS C:\> get-DMdisks -webSession $session

		OR

		PS C:\> $disks = get-DMdisks

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
    $Storagedisks = New-Object System.Collections.ArrayList

	foreach ($tdisk in $response)
	{
		$disk = [OceanStorDisks]::new($tdisk)
		$Storagedisks += $disk
	}

	$result = $Storagedisks

	return $result
}

function get-DMdisksbyPoolId{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks configured in a Storage Pool

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks configured in a given Storage Pool ID

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER poolId
		Mandatory parameter Storage Poll Id (int), to search for the disks configured

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage disks configured in a given Storage Pool

	.EXAMPLE

		PS C:\> get-DMdisksbyPoolId -webSession $session -poolID 1

		OR

		PS C:\> $disks = get-DMdisksbyPoolId $session -poolID 1

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
			[pscustomobject]$poolId
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
    $Storagedisks = New-Object System.Collections.ArrayList

	foreach ($tdisk in $response)
	{
		$disk = [OceanStorDisks]::new($tdisk)
		$Storagedisks += $disk
	}

	$result = $Storagedisks | Where-Object poolId -Match $poolID

	return $result
}

function get-DMdisksbyPoolName{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage disks configured in a Storage Pool

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage disks configured in a given Storage Pool Name

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER poolName
		Mandatory parameter Storage Poll Name (string), to search for the disks configured

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage disks configured in a given Storage Pool

	.EXAMPLE

		PS C:\> get-DMdisksbyPoolId -webSession $session poolName StoragePool001

		OR

		PS C:\> $disks = get-DMdisksbyPoolId $session poolName StoragePool001

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
		[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
			[pscustomobject]$poolName
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
    $Storagedisks = New-Object System.Collections.ArrayList

	foreach ($tdisk in $response)
	{
		$disk = [OceanStorDisks]::new($tdisk)
		$Storagedisks += $disk
	}

	$result = $Storagedisks | Where-Object poolName -Match $poolName

	return $result
}

function get-DMfreeDisks{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage free disks (not used)

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage free disks (not used)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage free disks (not used)

	.EXAMPLE

		PS C:\> get-DMfreeDisks -webSession $session

		OR

		PS C:\> $freeDisks = get-DMfreeDisks

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
    $Storagedisks = New-Object System.Collections.ArrayList

	foreach ($tdisk in $response)
	{
		$disk = [OceanStorDisks]::new($tdisk)
		$Storagedisks += $disk
	}

	$result = $Storagedisks | Where-Object logicType -eq "free"

	return $result
}

function get-DMcofferDisks{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage System coffer disks

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage System coffer disks

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage System coffer disks

	.EXAMPLE

		PS C:\> get-DMcofferDisks -webSession $session

		OR

		PS C:\> $cofferDisks = get-DMcofferDisks

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "disk" | Select-Object -ExpandProperty data
    $Storagedisks = New-Object System.Collections.ArrayList

	foreach ($tdisk in $response)
	{
		$disk = [OceanStorDisks]::new($tdisk)
		$Storagedisks += $disk
	}

	$result = $Storagedisks | Where-Object cofferDisk -eq $true

	return $result
}

function get-DMvStore{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage vStores configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage vStores configured in the system

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage vStores configured in the system. Array type return

	.EXAMPLE

		PS C:\> get-DMvStore -webSession $session

		OR

		PS C:\> $vStores = get-DMvStore

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "vstore" | Select-Object -ExpandProperty data
    $vStores = New-Object System.Collections.ArrayList

	foreach ($tvstore in $response)
	{
		$vStore = [OceanStorvStore]::new($tvstore)
		$vStores += $vStore
	}

	$result = $vStores

	return $result
}

function get-DMstoragePools{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage Pools Configured

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage Pools Configured in the system

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage pools in the system. Return an Array object.

	.EXAMPLE

		PS C:\> get-DMstoragePools -webSession $session

		OR

		PS C:\> $StoragePools = get-DMstoragePools

	.NOTES
		Filename: OceanstorPSModuleSys.ps1
		Author: Joao Carmona
		Modified date: 2022-05-22
		Version 0.2

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "storagepool" | Select-Object -ExpandProperty data
    $storagePools = New-Object System.Collections.ArrayList

	foreach ($spool in $response)
	{
		$storagepool = [OceanStorStoragePool]::new($spool)
		$storagePools += $storagepool
	}

	$result = $storagePools

	return $result
}