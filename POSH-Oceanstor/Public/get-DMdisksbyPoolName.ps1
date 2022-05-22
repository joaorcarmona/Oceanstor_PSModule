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
		Filename: get-DMdisksbyPoolName.ps1
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