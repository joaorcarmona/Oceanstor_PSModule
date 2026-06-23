function Get-DMAlarm {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage alarms

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage alarms (Unrecovered,Cleared,Recovered)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.PARAMETER AlarmStatus
		Optional alarm status filter. Valid values are Unrecovered, Cleared, and Recovered. If omitted, Unrecovered alarms are returned.

	.INPUTS
		System.Management.Automation.PSCustomObject

		You can pipe an OceanStor session object to WebSession.

	.OUTPUTS
		OceanStorAlarm

		Returns OceanStor alarm objects. Unrecovered alarms are returned by default.

	.EXAMPLE

		PS C:\> Get-DMAlarm -webSession $session -AlarmStatus "Cleared"

		OR

		PS C:\> $disks = Get-DMAlarm -AlarmStatus "Cleared"

	.EXAMPLE

		PS C:\> Get-DMAlarm -webSession $session

		OR

		PS C:\> $disks = Get-DMAlarm


	.NOTES
		Filename: Get-DMAlarm.ps1

	.LINK
	#>
    [Cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [ValidateSet('Unrecovered', 'Cleared', 'Recovered')]
        [string]$AlarmStatus
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $defaultDisplaySet = "Name", "Level", "Alarm Status", "Location", "Start time"

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    switch ($alarmStatus) {
        Unrecovered {
            $statusAlarm = 1
        }
        Cleared {
            $statusAlarm = 2
        }
        Recovered {
            $statusAlarm = 4
        }
        default {
            $statusAlarm = 1
        }
    }

    $response = Invoke-DeviceManager -WebSession $session -Method "GET" -Resource "alarm/historyalarm?filter=alarmStatus:$statusAlarm" | Select-Object -ExpandProperty data
    $alarms = New-Object System.Collections.ArrayList

    foreach ($talarm in $response) {
        $alarm = [OceanStorAlarm]::new($talarm, $session)
        [void]$alarms.Add($alarm)
    }

    $alarms | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    $result = $alarms
    return $result
}

Set-Alias -Name Get-DMAlarms -Value Get-DMAlarm
