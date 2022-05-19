function get-DMluns{
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

	foreach ($tlun in $response)
	{
		$lun = [OceanstorDeviceLun]::new($tlun)
		$StorageLuns += $lun
	}

	$result = $storageLuns

	return $result
}

function get-DMlunsByWWN{
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [pscustomobject]$wwn
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lun" | Select-Object -ExpandProperty data
    $StorageLuns = New-Object System.Collections.ArrayList

	foreach ($tlun in $response)
	{
		$lun = [OceanstorDeviceLun]::new($tlun)
		$StorageLuns += $lun
	}

	$result = $StorageLuns | Where-Object wwn -Match $wwn

	return $result
}


function get-DMlunGroups{
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "lungroup" | Select-Object -ExpandProperty data
    $lunGroups = New-Object System.Collections.ArrayList

	foreach ($lgroup in $response)
	{
		$lunGroup = [OceanStorLunGroup]::new($lgroup)
		$lunGroups += $lunGroup
	}

	$result = $lunGroups

	return $result
}

function get-DMhosts{
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "host" | Select-Object -ExpandProperty data
    $hosts = New-Object System.Collections.ArrayList

	foreach ($thost in $response)
	{
		$hostobj = [OceanStorHost]::new($thost)
		$hosts += $hostobj
	}

	$result = $hosts

	return $result
}

function get-DMhostGroups{
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "hostgroup" | Select-Object -ExpandProperty data
    $hostgroups = New-Object System.Collections.ArrayList

	foreach ($hgroup in $response)
	{
		$hostgroup = [OceanStorHostGroup]::new($hgroup)
		$hostgroups += $hostgroup
	}

	$result = $hostgroups

	return $result
}

function get-DMhostGroups{
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
		$storagePool = [OceanStorStoragePool]::new($spool)
		$storagePools += $storagePool
	}

	$result = $storagePools

	return $result
}
