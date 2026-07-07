class OceanstorReplicationConsistencyGroup {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Health Status}
    [string]${Health Status Code}
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Recovery Policy}
    [string]${Replication Mode}
    [string]$Speed
    [string]${Start Time}
    [string]${End Time}
    [string]${DR Ring Id}

    OceanstorReplicationConsistencyGroup([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('NAME', 'name'))
        $this.Description = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('DESCRIPTION', 'description'))
        $this.{Health Status Code} = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('HEALTHSTATUS'))
        $this.{Running Status Code} = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Health Status} = [OceanstorReplicationConsistencyGroup]::ConvertHealthStatus($this.{Health Status Code})
        $this.{Running Status} = [OceanstorReplicationConsistencyGroup]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Recovery Policy} = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('RECOVERYPOLICY'))
        $this.{Replication Mode} = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('REPLICATIONMODEL'))
        $this.Speed = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('SPEED'))
        $this.{Start Time} = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('STARTTIME'))
        $this.'End Time' = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('ENDTIME'))
        $this.{DR Ring Id} = [OceanstorReplicationConsistencyGroup]::GetString($Source, @('DRRINGID'))
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
        $value = [OceanstorReplicationConsistencyGroup]::GetValue($Source, $Names)
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
            default { return $Code }
        }
        return $Code
    }
}
