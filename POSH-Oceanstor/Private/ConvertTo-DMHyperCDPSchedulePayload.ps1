function ConvertTo-DMHyperCDPSchedulePayload {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [string]$Name,
        [string]$Description,
        [ValidateSet('Block', 'File')]
        [string]$ObjectType = 'Block',
        [int]$FrequencyValueSeconds,
        [int]$FrequencySnapshotCount,
        [int[]]$DayHours,
        [int]$DayMinute,
        [int]$DailySnapshotCount,
        [int[]]$WeeklyDays,
        [string]$StartTimeOfWeek,
        [int]$WeeklySnapshotCount,
        [string[]]$MonthDays,
        [string]$StartTimeOfMonth,
        [int]$MonthlySnapshotCount,
        [string]$VstoreId,
        [switch]$ForUpdate
    )

    function Test-DMPolicyTriplet {
        param(
            [string]$PolicyName,
            [bool[]]$Present
        )

        $presentCount = @($Present | Where-Object { $_ }).Count
        if ($presentCount -gt 0 -and $presentCount -lt $Present.Count) {
            throw "$PolicyName policy parameters must be supplied together."
        }
        return ($presentCount -eq $Present.Count)
    }

    $body = @{}
    if (-not $ForUpdate -or $PSBoundParameters.ContainsKey('Name')) {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            throw 'Name is required.'
        }
        if ($Name.Length -gt 31) {
            throw 'Name must contain 1 to 31 characters.'
        }
        $body.NAME = $Name
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        if ($null -ne $Description -and $Description.Length -gt 255) {
            throw 'Description cannot exceed 255 characters.'
        }
        $body.DESCRIPTION = $Description
    }
    if (-not $ForUpdate -or $PSBoundParameters.ContainsKey('ObjectType')) {
        $body.OBJECTTYPE = if ($ObjectType -eq 'File') { '1' } else { '0' }
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $body.SCHEDULETYPE = 1

    $hasFrequency = Test-DMPolicyTriplet -PolicyName 'Fixed-period' -Present @(
        $PSBoundParameters.ContainsKey('FrequencyValueSeconds'),
        $PSBoundParameters.ContainsKey('FrequencySnapshotCount')
    )
    if ($hasFrequency) {
        if ($FrequencyValueSeconds -lt 3 -or $FrequencyValueSeconds -gt 86400) {
            throw 'FrequencyValueSeconds must be between 3 and 86400.'
        }
        if ($FrequencySnapshotCount -lt 1) {
            throw 'FrequencySnapshotCount must be greater than zero.'
        }
        $body.FREQUENCYVALUE = $FrequencyValueSeconds
        $body.FREQUENCYNUM = $FrequencySnapshotCount
    }

    $hasDaily = Test-DMPolicyTriplet -PolicyName 'Daily' -Present @(
        $PSBoundParameters.ContainsKey('DayHours'),
        $PSBoundParameters.ContainsKey('DayMinute'),
        $PSBoundParameters.ContainsKey('DailySnapshotCount')
    )
    if ($hasDaily) {
        foreach ($hour in $DayHours) {
            if ($hour -lt 0 -or $hour -gt 23) {
                throw 'DayHours values must be between 0 and 23.'
            }
        }
        if ($DayMinute -lt 0 -or $DayMinute -gt 59) {
            throw 'DayMinute must be between 0 and 59.'
        }
        if ($DailySnapshotCount -lt 1 -or $DailySnapshotCount -gt 512) {
            throw 'DailySnapshotCount must be between 1 and 512.'
        }
        $body.DAYHOURS = @($DayHours)
        $body.DAYMINUTE = $DayMinute
        $body.DAILYSNAPSHOTNUM = $DailySnapshotCount
    }

    $hasWeekly = Test-DMPolicyTriplet -PolicyName 'Weekly' -Present @(
        $PSBoundParameters.ContainsKey('WeeklyDays'),
        $PSBoundParameters.ContainsKey('StartTimeOfWeek'),
        $PSBoundParameters.ContainsKey('WeeklySnapshotCount')
    )
    if ($hasWeekly) {
        foreach ($day in $WeeklyDays) {
            if ($day -lt 0 -or $day -gt 6) {
                throw 'WeeklyDays values must be between 0 (Sunday) and 6 (Saturday).'
            }
        }
        if ($StartTimeOfWeek -notmatch '^([01]\d|2[0-3]):[0-5]\d$') {
            throw 'StartTimeOfWeek must use HH:MM format.'
        }
        if ($WeeklySnapshotCount -lt 1 -or $WeeklySnapshotCount -gt 256) {
            throw 'WeeklySnapshotCount must be between 1 and 256.'
        }
        $body.WEEKLYDAYS = @($WeeklyDays)
        $body.STARTTIMEOFWEEK = $StartTimeOfWeek
        $body.WEEKLYSNAPSHOTNUM = $WeeklySnapshotCount
    }

    $hasMonthly = Test-DMPolicyTriplet -PolicyName 'Monthly' -Present @(
        $PSBoundParameters.ContainsKey('MonthDays'),
        $PSBoundParameters.ContainsKey('StartTimeOfMonth'),
        $PSBoundParameters.ContainsKey('MonthlySnapshotCount')
    )
    if ($hasMonthly) {
        foreach ($day in $MonthDays) {
            $parsedDay = 0
            if ($day -ne 'lastday' -and (-not [int]::TryParse($day, [ref]$parsedDay) -or $parsedDay -lt 1 -or $parsedDay -gt 31)) {
                throw 'MonthDays values must be integers from 1 to 31 or lastday.'
            }
        }
        if ($StartTimeOfMonth -notmatch '^([01]\d|2[0-3]):[0-5]\d$') {
            throw 'StartTimeOfMonth must use HH:MM format.'
        }
        if ($MonthlySnapshotCount -lt 1 -or $MonthlySnapshotCount -gt 256) {
            throw 'MonthlySnapshotCount must be between 1 and 256.'
        }
        $body.MONTHDAYS = @($MonthDays)
        $body.STARTTIMEOFMONTH = $StartTimeOfMonth
        $body.MONTHSNAPSHOTNUM = $MonthlySnapshotCount
    }

    if (-not $ForUpdate -and -not ($hasFrequency -or $hasDaily -or $hasWeekly -or $hasMonthly)) {
        throw 'At least one non-secure schedule policy must be supplied.'
    }

    if ($ForUpdate -and $body.Count -eq 1 -and $body.ContainsKey('SCHEDULETYPE')) {
        throw 'At least one schedule property or policy must be supplied.'
    }

    return $body
}
