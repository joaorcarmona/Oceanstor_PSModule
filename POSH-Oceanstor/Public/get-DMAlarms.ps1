function get-DMAlarms{
	<#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage alarms

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage alarms (Unrecovered,Cleared,Recovered)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage active alarms by default

	.EXAMPLE

		PS C:\> get-DMAlarms -webSession $session -AlarmStatus "Cleared"

		OR

		PS C:\> $disks = get-DMAlarms -AlarmStatus "Cleared"

	.EXAMPLE

		PS C:\> get-DMAlarms -webSession $session

		OR

		PS C:\> $disks = get-DMAlarms


	.NOTES
		Filename: get-DMAlarms.ps1
		Author: Joao Carmona
		Modified date: 2022-05-24
		Version 0.1

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
	[Parameter(ValueFromPipeline=$false,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
	[ValidateSet('Unrecovered','Cleared','Recovered')]
        [string]$AlarmStatus
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

	switch ($alarmStatus) {
		Unrecovered {$statusAlarm = 1}
		Cleared {$statusAlarm = 2}
		Recovered {$statusAlarm = 4}
		default {$statusAlarm = 1}
	}

    $response = invoke-DeviceManager -WebSession $session -Method "GET" -Resource "alarm/historyalarm?filter=alarmStatus:$statusAlarm" | Select-Object -ExpandProperty data
    $alarms = New-Object System.Collections.ArrayList

	foreach ($talarm in $response)
	{
		$alarm = [OceanStorAlarm]::new($talarm)
		$alarms += $alarm
	}

	$result = $alarms
	return $result
}