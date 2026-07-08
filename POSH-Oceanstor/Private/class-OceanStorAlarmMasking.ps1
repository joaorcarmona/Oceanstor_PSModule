[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '')]
class OceanStorAlarmMasking {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    # Define Properties
    [string]${Alarm Id}
    [string]${Name}
    [string]${Level}
    [string]${Alarm Object Type}
    [string]${Alarm Object Type Id}
    [bool]${Masked}
    [bool]${Uncleared Alarm Exists}
    [string]${Id}
    [string]${Type}

    OceanStorAlarmMasking ([pscustomobject]$MaskingReceived, [pscustomobject]$WebSession, [hashtable]$ObjectTypeMap)
    {
        $this.Session = $WebSession
        $this.WebSession = $WebSession

        $this.{Alarm Id} = $MaskingReceived.CMO_ALARM_ID
        $this.{Name} = $MaskingReceived.CMO_ALARM_NAME
        $this.{Id} = $MaskingReceived.ID
        $this.{Type} = switch ([string]$MaskingReceived.TYPE)
        {
            '16435' { $this.{Type} = 'ALARM_DEFINITION' }
            Default { $this.{Type} = [string]$MaskingReceived.TYPE }
        }

        # The API returns the object type as a numeric value. Keep it in
        # "Alarm Object Type Id" for correlation, and translate it to a friendly
        # name via the Get-DMAlarmType catalog map when the caller supplies one
        # (falling back to the numeric value for object types absent from the
        # catalog).
        $objTypeId = [string]$MaskingReceived.CMO_ALARM_OBJ_TYPE
        $this.{Alarm Object Type Id} = $objTypeId
        if ($ObjectTypeMap -and $ObjectTypeMap.ContainsKey($objTypeId)) {
            $this.{Alarm Object Type} = $ObjectTypeMap[$objTypeId]
        }
        else {
            $this.{Alarm Object Type} = $objTypeId
        }

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
