[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
class OceanStorAlarm{
	hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
	#Define Properties
    [string]${Alarm Object Type}
    [string]${Alarm Status}
    [string]${Cleared By}
    [nullable[datetime]]${Cleared Time}
    [string]${Confirmed Alarm}
    [string]${Description}
    [string]${Details}
    [string]${Decimal Id}
    [string]${Alarm Parameters}
    [string]${Event Type}
    [string]${Level}
    [string]${Location}
    [string]${Name}
    [nullable[datetime]]${Recover Time}
    [string]${Alarm SN}
    [string]${Alarm src Id}
    [string]${Alarm src Type}
    [nullable[datetime]]${Start time}
    [string]${Hexadecimal ID}
    [string]${Suggestion Action}
    [string]${Type}

	OceanStorAlarm ([array]$AlarmReceived, [pscustomobject]$WebSession)
	{
        $this.Session = $WebSession
		$this.WebSession = $WebSession
        $this.{Alarm Object Type} = $AlarmReceived.alarmObjType
        $this.{Cleared By} = $AlarmReceived.clearName

        if ($AlarmReceived.ClearTime -ne 0) {
            $this.{Cleared Time} = [datetimeoffset]::FromUnixTimeSeconds($AlarmReceived.clearTime).LocalDateTime
        } else {
            $this.{Cleared Time} = $null
        }

        $this.{Confirmed Alarm} = $AlarmReceived.confirmTime
        $this.{Description} = $AlarmReceived.description
        $this.{Details} = $AlarmReceived.detail
        $this.{Decimal Id} = $AlarmReceived.eventID
        $this.{Alarm Parameters} = $AlarmReceived.eventParam
        $this.{Location} = $AlarmReceived.location
        $this.{Name} = $AlarmReceived.name

        if ($AlarmReceived.recoverTime -ne 0) {
            $this.{Recover Time} = [datetimeoffset]::FromUnixTimeSeconds($AlarmReceived.recoverTime).LocalDateTime
        } else {
            $this.{Recover Time} = $null
        }

        $this.{Alarm SN} = $AlarmReceived.sequence
        $this.{Alarm src Id} = $AlarmReceived.sourceID
        $this.{Alarm src Type} = $AlarmReceived.sourceType

        if ($AlarmReceived.startTime -ne 0) {
            $this.{Start time} = [datetimeoffset]::FromUnixTimeSeconds($AlarmReceived.startTime).LocalDateTime
        } else {
            $this.{Start time} = $null
        }

        $this.{Hexadecimal ID} = $AlarmReceived.strEventID
        $this.{Suggestion Action} = $AlarmReceived.suggestion

        switch($AlarmReceived.alarmStatus)
		{
			1 {$this.{Alarm Status} = "unrecovered"}
            2 {$this.{Alarm Status} = "cleared"}
            4 {$this.{Alarm Status} = "Recovered"}
		}

        switch($AlarmReceived.level)
		{
			2 {$this.{Level} = "info"}
            3 {$this.{Level} = "warning"}
            5 {$this.{Level} = "major"}
            6 {$this.{Level} = "critical"}
		}

        switch($AlarmReceived.type)
		{
			0 {$this.{Type} = "event"}
            1 {$this.{Type} = "alarm"}
            2 {$this.{Type} = "cleared alarm"}
            3 {$this.{Type} = "operation log"}
            4 {$this.{Type} = "running log"}
            10 {$this.{Type} = "security log"}
		}

		switch($AlarmReceived.eventType)
		{
			1 {$this.{Event Type} = "alarm"}
            2 {$this.{Event Type} = "cleared alarm"}
            3 {$this.{Event Type} = "operation log"}
            4 {$this.{Event Type} = "running log"}
            10 {$this.{Event Type} = "security log"}
		}

	}
}


