[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
class OceanStorAlarmMasking {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    # Define Properties
    [string]${Alarm Id}
    [string]${Name}
    [string]${Level}
    [string]${Alarm Object Type}
    [bool]${Masked}
    [bool]${Uncleared Alarm Exists}
    [string]${Id}
    [string]${Type}

    OceanStorAlarmMasking ([pscustomobject]$MaskingReceived, [pscustomobject]$WebSession)
    {
        $this.Session = $WebSession
        $this.WebSession = $WebSession

        $this.{Alarm Id} = $MaskingReceived.CMO_ALARM_ID
        $this.{Name} = $MaskingReceived.CMO_ALARM_NAME
        # Object type is returned as its numeric value; resolve names via Get-DMAlarmType.
        $this.{Alarm Object Type} = $MaskingReceived.CMO_ALARM_OBJ_TYPE
        $this.{Id} = $MaskingReceived.ID
        $this.{Type} = $MaskingReceived.TYPE

        # enableClose and isExistAlarm are returned as string booleans ("true"/"false").
        $this.{Masked} = ($MaskingReceived.enableClose -eq 'true')
        $this.{Uncleared Alarm Exists} = ($MaskingReceived.isExistAlarm -eq 'true')

        switch ([string]$MaskingReceived.CMO_ALARM_LEVEL)
        {
            '2' { $this.{Level} = 'info' }
            '3' { $this.{Level} = 'warning' }
            '5' { $this.{Level} = 'major' }
            '6' { $this.{Level} = 'critical' }
            default { $this.{Level} = $MaskingReceived.CMO_ALARM_LEVEL }
        }
    }
}
