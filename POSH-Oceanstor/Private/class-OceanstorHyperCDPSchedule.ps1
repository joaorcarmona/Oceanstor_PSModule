class OceanstorHyperCDPSchedule {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [string]${Object Type}
    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Schedule Type}
    [string]${Target Object Type}
    [bool]$Enabled
    [string]${Running Status}
    [string]${Health Status}
    [string]${Last Execution Result}
    [string]${Last Execution Time}
    [string]${Frequency Value Seconds}
    [string]${Frequency Snapshot Count}
    [string]${Day Hours}
    [string]${Day Minute}
    [string]${Daily Snapshot Count}
    [string]${Weekly Days}
    [string]${Start Time Of Week}
    [string]${Weekly Snapshot Count}
    [string]${Month Days}
    [string]${Start Time Of Month}
    [string]${Monthly Snapshot Count}
    [string]${LUN Count}
    [string]${FileSystem Count}
    [string]${Protection Group Count}
    [bool]${Secure Snapshot Enabled}
    [string]${Protection Period}
    [string]${Protection Period Unit}
    [string]${vStore Id}
    [string]${vStore Name}

    OceanstorHyperCDPSchedule([pscustomobject]$ScheduleReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.{Object Type} = 'HyperCDP Schedule'
        $this.Id = $ScheduleReceived.ID
        $this.Name = $ScheduleReceived.NAME
        $this.Description = $ScheduleReceived.DESCRIPTION
        $this.{Schedule Type} = switch ([string]$ScheduleReceived.SCHEDULETYPE) {
            '1' { 'HyperCDP' }
            '0' { 'Timing Snapshot (Deprecated)' }
            default { $ScheduleReceived.SCHEDULETYPE }
        }
        $this.{Target Object Type} = switch ([string]$ScheduleReceived.OBJECTTYPE) {
            '0' { 'Block' }
            '1' { 'File' }
            default { $ScheduleReceived.OBJECTTYPE }
        }
        $this.Enabled = switch ($ScheduleReceived.ENABLESCHEDULE) {
            { $_ -eq $true -or $_ -eq 'true' -or $_ -eq '1' -or $_ -eq 1 } { $true }
            default { $false }
        }
        $this.{Running Status} = switch ([string]$ScheduleReceived.RUNNINGSTATUS) {
            '30' { 'Enabled' }
            '31' { 'Disabled' }
            '53' { 'Initializing' }
            '106' { 'Deleting' }
            '111' { 'Stopping' }
            default { $ScheduleReceived.RUNNINGSTATUS }
        }
        $this.{Health Status} = switch ([string]$ScheduleReceived.HEALTHSTATUS) {
            '1' { 'Normal' }
            '2' { 'Faulty' }
            default { $ScheduleReceived.HEALTHSTATUS }
        }
        $this.{Last Execution Result} = switch ([string]$ScheduleReceived.LASTEXECUTIONRESULT) {
            '1' { 'Success' }
            '2' { 'Failure' }
            default { $ScheduleReceived.LASTEXECUTIONRESULT }
        }
        $this.{Last Execution Time} = $ScheduleReceived.LASTEXECUTIONTIME
        $this.{Frequency Value Seconds} = $ScheduleReceived.FREQUENCYVALUE
        $this.{Frequency Snapshot Count} = $ScheduleReceived.FREQUENCYNUM
        $this.{Day Hours} = $ScheduleReceived.DAYHOURS
        $this.{Day Minute} = $ScheduleReceived.DAYMINUTE
        $this.{Daily Snapshot Count} = $ScheduleReceived.DAILYSNAPSHOTNUM
        $this.{Weekly Days} = $ScheduleReceived.WEEKLYDAYS
        $this.{Start Time Of Week} = $ScheduleReceived.STARTTIMEOFWEEK
        $this.{Weekly Snapshot Count} = $ScheduleReceived.WEEKLYSNAPSHOTNUM
        $this.{Month Days} = $ScheduleReceived.MONTHDAYS
        $this.{Start Time Of Month} = $ScheduleReceived.STARTTIMEOFMONTH
        $this.{Monthly Snapshot Count} = $ScheduleReceived.MONTHSNAPSHOTNUM
        $this.{LUN Count} = $ScheduleReceived.lunNum
        $this.{FileSystem Count} = $ScheduleReceived.fsNum
        $this.{Protection Group Count} = $ScheduleReceived.protectionGroupNum
        $this.{Secure Snapshot Enabled} = switch ($ScheduleReceived.SECURESNAPENABLED) {
            { $_ -eq $true -or $_ -eq 'true' -or $_ -eq '1' -or $_ -eq 1 } { $true }
            default { $false }
        }
        $this.{Protection Period} = $ScheduleReceived.PROTECTPERIOD
        $this.{Protection Period Unit} = switch ([string]$ScheduleReceived.PROTECTPERIODUNIT) {
            '46' { 'Day' }
            '47' { 'Month' }
            '48' { 'Year' }
            default { $ScheduleReceived.PROTECTPERIODUNIT }
        }
        $this.{vStore Id} = $ScheduleReceived.vstoreId
        $this.{vStore Name} = $ScheduleReceived.vstoreName
    }

    [psobject] Enable() {
        return Enable-DMHyperCDPSchedule -WebSession $this.Session -ScheduleId $this.Id -Confirm:$false
    }

    [psobject] Disable() {
        return Disable-DMHyperCDPSchedule -WebSession $this.Session -ScheduleId $this.Id -Confirm:$false
    }

    [psobject] Delete() {
        return Remove-DMHyperCDPSchedule -WebSession $this.Session -ScheduleId $this.Id -Confirm:$false
    }
}
