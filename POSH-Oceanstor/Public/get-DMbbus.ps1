function get-dmbbus {
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

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "backup_power" | Select-Object -ExpandProperty data
    $bbus = New-Object System.Collections.ArrayList

    foreach ($bbu in $response)
	{
        $bbu = [OceanstorBBU]::new($bbu)
		$bbus += $bbu
	}

	$result = $bbus

	return $result
}
