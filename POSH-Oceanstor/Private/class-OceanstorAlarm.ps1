class OceanStorAlarm{
	#Define Properties
    [string]${Alarm Object Type}
    [string]${Alarm Status}
    [string]${Username Cleared}
    [string]${Cleared Time}
    [string]${Confirmed Alarm}
    [string]${Description}
    [string]${Details}
    [string]${Decimal Id}
    [string]${Alarm Parameters}
    [string]${Event Type}
    [string]${Level}
    [string]${Location}
    [string]${Name}
    [string]${Recover Time}
    [string]${Alarm SN}
    [string]${Alarm src Id}
    [string]${Alarm src Type}
    [string]${Start time}
    [string]${Hexadecimal ID}
    [string]${Suggestion Action}
    [string]${Type}

	OceanStorAlarm ([array]$AlarmReceived)
	{
        $this.{Alarm Object Type} = $AlarmReceived.alarmObjType
        $this.{Username Cleared} = $AlarmReceived.clearName

        if ($AlarmReceived.ClearTime -ne 0) {
            $this.{Cleared Time} = $(New-TimeSpan -Seconds $AlarmReceived.clearTime).ToString()
        } else {
            $this.{Cleared Time} = $AlarmReceived.clearTime
        }

        $this.{Confirmed Alarm} = $AlarmReceived.confirmTime
        $this.{Description} = $AlarmReceived.description
        $this.{Details} = $AlarmReceived.detail
        $this.{Decimal Id} = $AlarmReceived.eventID
        $this.{Alarm Parameters} = $AlarmReceived.eventParam
        $this.{Location} = $AlarmReceived.location
        $this.{Name} = $AlarmReceived.name

        if ($AlarmReceived.recoverTime -ne 0) {
            $this.{Recover Time} = $(New-TimeSpan -Seconds $AlarmReceived.recoverTime).ToString()
        } else {
            $this.{Recover Time} = $AlarmReceived.recoverTime
        }

        $this.{Alarm SN} = $AlarmReceived.sequence
        $this.{Alarm src Id} = $AlarmReceived.sourceID
        $this.{Alarm src Type} = $AlarmReceived.sourceType

        if ($AlarmReceived.startTime -ne 0) {
            $this.{Start time} = $(New-TimeSpan -Seconds $AlarmReceived.startTime).ToString()
        } else {
            $this.{Start time} = $AlarmReceived.startTime
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
			1 {$this.{Level} = "info"}
            2 {$this.{Level} = "warning"}
            3 {$this.{Level} = "major"}
            4 {$this.{Level} = "critical"}
		}

        switch($AlarmReceived.type)
		{
			0 {$this.{Type} = "event"}
            1 {$this.{Type} = "alarm"}
            2 {$this.{Type} = "cleared alarm"}
            3 {$this.{Type} = "operation log"}
            4 {$this.{Type} = "running log"}
		}

		switch($AlarmReceived.eventType)
		{
			1 {$this.{Event Type} = "alarm"}
            2 {$this.{Event Type} = "cleared alarm"}
            3 {$this.{Event Type} = "operation log"}
            4 {$this.{Event Type} = "running log"}
		}

	}
}