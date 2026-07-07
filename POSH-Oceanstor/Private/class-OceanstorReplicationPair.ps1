class OceanstorReplicationPair {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]${Health Status}
    [string]${Health Status Code}
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Is Primary}
    [string]${Local Resource Id}
    [string]${Local Resource Name}
    [string]${Local Resource Type}
    [string]${Remote Device Id}
    [string]${Remote Device Name}
    [string]${Remote Device SN}
    [string]${Remote Resource Id}
    [string]${Remote Resource Name}
    [string]${Synchronization Type}
    [string]${Recovery Policy}
    [string]$Speed
    [string]${Replication Mode}
    [string]${Replication Progress}
    [string]${Synchronization Schedule}
    [string]${Initial Sync Type}
    [string]${vStore Pair Id}
    [string]${vStore Id}
    [string]${vStore Name}

    OceanstorReplicationPair([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorReplicationPair]::GetString($Source, @('ID', 'id'))
        $this.{Health Status Code} = [OceanstorReplicationPair]::GetString($Source, @('HEALTHSTATUS'))
        $this.{Running Status Code} = [OceanstorReplicationPair]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Health Status} = [OceanstorReplicationPair]::ConvertHealthStatus($this.{Health Status Code})
        $this.{Running Status} = [OceanstorReplicationPair]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Is Primary} = [OceanstorReplicationPair]::GetString($Source, @('ISPRIMARY'))
        $this.{Local Resource Id} = [OceanstorReplicationPair]::GetString($Source, @('LOCALRESID'))
        $this.{Local Resource Name} = [OceanstorReplicationPair]::GetString($Source, @('LOCALRESNAME'))
        $this.{Local Resource Type} = [OceanstorReplicationPair]::GetString($Source, @('LOCALRESTYPE'))
        $this.{Remote Device Id} = [OceanstorReplicationPair]::GetString($Source, @('REMOTEDEVICEID'))
        $this.{Remote Device Name} = [OceanstorReplicationPair]::GetString($Source, @('REMOTEDEVICENAME'))
        $this.{Remote Device SN} = [OceanstorReplicationPair]::GetString($Source, @('REMOTEDEVICESN'))
        $this.{Remote Resource Id} = [OceanstorReplicationPair]::GetString($Source, @('REMOTERESID'))
        $this.{Remote Resource Name} = [OceanstorReplicationPair]::GetString($Source, @('REMOTERESNAME'))
        $this.{Synchronization Type} = [OceanstorReplicationPair]::GetString($Source, @('SYNCHRONIZETYPE'))
        $this.{Recovery Policy} = [OceanstorReplicationPair]::GetString($Source, @('RECOVERYPOLICY'))
        $this.Speed = [OceanstorReplicationPair]::GetString($Source, @('SPEED'))
        $this.{Replication Mode} = [OceanstorReplicationPair]::GetString($Source, @('REPLICATIONMODEL'))
        $this.{Replication Progress} = [OceanstorReplicationPair]::GetString($Source, @('REPLICATIONPROGRESS'))
        $this.{Synchronization Schedule} = [OceanstorReplicationPair]::GetString($Source, @('SYNCHRONIZESCHEDULE'))
        $this.{Initial Sync Type} = [OceanstorReplicationPair]::GetString($Source, @('initialSyncType'))
        $this.{vStore Pair Id} = [OceanstorReplicationPair]::GetString($Source, @('VSTOREPAIRID'))
        $this.{vStore Id} = [OceanstorReplicationPair]::GetString($Source, @('vstoreId'))
        $this.{vStore Name} = [OceanstorReplicationPair]::GetString($Source, @('vstoreName'))
    }

    static [object] GetValue([object]$Source, [string[]]$Names) {
        if ($null -eq $Source) { return $null }
        foreach ($name in $Names) {
            $property = $Source.PSObject.Properties[$name]
            if ($null -ne $property) { return $property.Value }
        }
        return $null
    }

    static [string] GetString([object]$Source, [string[]]$Names) {
        $value = [OceanstorReplicationPair]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    static [string] ConvertHealthStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '2' { return 'Faulty' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertRunningStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '23' { return 'Synchronizing' }
            '26' { return 'Split' }
            '33' { return 'Normal' }
            '34' { return 'Interrupted' }
            '35' { return 'Invalid' }
            default { return $Code }
        }
        return $Code
    }
}
