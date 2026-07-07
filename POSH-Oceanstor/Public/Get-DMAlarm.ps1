function Get-DMAlarm {
    <#
	.SYNOPSIS
		To Get Huawei Oceanstor Storage alarms

	.DESCRIPTION
		Function to request Huawei Oceanstor Storage alarms (Unrecovered,Cleared,Recovered)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

	.PARAMETER AlarmStatus
		Optional alarm status filter. Valid values are Unrecovered, Cleared, and Recovered. If omitted, Unrecovered alarms are returned.

	.PARAMETER StartTime
		Optional. Only return alarms generated at or after this time. Converted to a Unix epoch second
		and combined with -EndTime (defaulting to now) as a REST startTime:[start,end] range filter.
		Cannot be combined with -Last.

	.PARAMETER EndTime
		Optional. Only return alarms generated at or before this time. Converted to a Unix epoch second
		and combined with -StartTime (defaulting to epoch 0) as a REST startTime:[start,end] range filter.
		Cannot be combined with -Last.

	.PARAMETER Last
		Optional convenience filter: return alarms generated within this timespan of now. Equivalent to
		-StartTime (Get-Date) - Last -EndTime (Get-Date). Cannot be combined with -StartTime/-EndTime.

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

	.EXAMPLE

		PS C:\> Get-DMAlarm -AlarmStatus Unrecovered -Last (New-TimeSpan -Hours 24)

	.EXAMPLE

		PS C:\> Get-DMAlarm -StartTime (Get-Date).AddDays(-7) -EndTime (Get-Date)

	.NOTES
		Filename: Get-DMAlarm.ps1

	.LINK
	#>
    [Cmdletbinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [ValidateSet('Unrecovered', 'Cleared', 'Recovered')]
        [string]$AlarmStatus,
        [Parameter(Mandatory = $false)]
        [datetime]$StartTime,
        [Parameter(Mandatory = $false)]
        [datetime]$EndTime,
        [Parameter(Mandatory = $false)]
        [timespan]$Last
    )

    if ($Last -and ($PSBoundParameters.ContainsKey('StartTime') -or $PSBoundParameters.ContainsKey('EndTime'))) {
        throw '-Last cannot be combined with -StartTime or -EndTime.'
    }

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
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

    $filter = "alarmStatus::$statusAlarm"

    $hasStartTime = $PSBoundParameters.ContainsKey('StartTime')
    $hasEndTime = $PSBoundParameters.ContainsKey('EndTime')

    if ($Last) {
        $EndTime = Get-Date
        $StartTime = $EndTime - $Last
        $hasStartTime = $true
        $hasEndTime = $true
    }

    if ($hasStartTime -or $hasEndTime) {
        if (-not $hasEndTime) {
            $EndTime = Get-Date
        }
        if (-not $hasStartTime) {
            $StartTime = [System.DateTimeOffset]::FromUnixTimeSeconds(0).DateTime
        }
        $startEpoch = [System.DateTimeOffset]::new($StartTime.ToUniversalTime()).ToUnixTimeSeconds()
        $endEpoch = [System.DateTimeOffset]::new($EndTime.ToUniversalTime()).ToUnixTimeSeconds()
        $filter += " and startTime:[$startEpoch,$endEpoch]"
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource "alarm/historyalarm?filter=$filter"
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
