class OceanstorVStorePair {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]${Replication Type}
    [string]${Replication Type Code}
    [string]${Health Status}
    [string]${Health Status Code}
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Link Status}
    [string]${Link Status Code}
    [string]${Config Status}
    [string]${Config Status Code}
    [string]${Local vStore Id}
    [string]${Local vStore Name}
    [string]${Remote vStore Id}
    [string]${Remote vStore Name}
    [string]${Remote Device Id}
    [string]${Remote Device Name}
    [string]${Remote Device SN}
    [string]${Domain Id}
    [string]${Domain Name}
    [string]$Role
    [string]$Access

    OceanstorVStorePair([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorVStorePair]::GetString($Source, @('ID', 'id'))
        $this.{Replication Type Code} = [OceanstorVStorePair]::GetString($Source, @('REPTYPE'))
        $this.{Replication Type} = [OceanstorVStorePair]::ConvertReplicationType($this.{Replication Type Code})
        $this.{Health Status Code} = [OceanstorVStorePair]::GetString($Source, @('HEALTHSTATUS'))
        $this.{Health Status} = [OceanstorVStorePair]::ConvertHealthStatus($this.{Health Status Code})
        $this.{Running Status Code} = [OceanstorVStorePair]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Running Status} = [OceanstorVStorePair]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Link Status Code} = [OceanstorVStorePair]::GetString($Source, @('LINKSTATUS'))
        $this.{Link Status} = [OceanstorVStorePair]::ConvertLinkStatus($this.{Link Status Code})
        $this.{Config Status Code} = [OceanstorVStorePair]::GetString($Source, @('CONFIGSTATUS'))
        $this.{Config Status} = [OceanstorVStorePair]::ConvertConfigStatus($this.{Config Status Code})
        $this.{Local vStore Id} = [OceanstorVStorePair]::GetString($Source, @('LOCALVSTOREID'))
        $this.{Local vStore Name} = [OceanstorVStorePair]::GetString($Source, @('LOCALVSTORENAME'))
        $this.{Remote vStore Id} = [OceanstorVStorePair]::GetString($Source, @('REMOTEVSTOREID'))
        $this.{Remote vStore Name} = [OceanstorVStorePair]::GetString($Source, @('REMOTEVSTORENAME'))
        $this.{Remote Device Id} = [OceanstorVStorePair]::GetString($Source, @('REMOTEDEVICEID'))
        $this.{Remote Device Name} = [OceanstorVStorePair]::GetString($Source, @('REMOTEDEVICENAME'))
        $this.{Remote Device SN} = [OceanstorVStorePair]::GetString($Source, @('REMOTEDEVICESN'))
        $this.{Domain Id} = [OceanstorVStorePair]::GetString($Source, @('DOMAINID'))
        $this.{Domain Name} = [OceanstorVStorePair]::GetString($Source, @('DOMAINNAME'))
        $this.Role = [OceanstorVStorePair]::GetString($Source, @('ROLE', 'role'))
        $this.Access = [OceanstorVStorePair]::GetString($Source, @('access'))
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
        $value = [OceanstorVStorePair]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    static [string] ConvertReplicationType([string]$Code) {
        switch ($Code) {
            '1' { return 'HyperMetro' }
            '2' { return 'RemoteReplication' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertHealthStatus([string]$Code) {
        switch ($Code) {
            '0' { return 'Unknown' }
            '1' { return 'Normal' }
            '2' { return 'Faulty' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertRunningStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '25' { return 'Unsynchronized' }
            '26' { return 'Split' }
            '35' { return 'Invalid' }
            '93' { return 'ForceStarted' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertLinkStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Connected' }
            '2' { return 'NotConnected' }
            '3' { return 'AirGapLinkDown' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertConfigStatus([string]$Code) {
        switch ($Code) {
            '0' { return 'Normal' }
            '1' { return 'Synchronizing' }
            '2' { return 'ToBeSynchronized' }
            default { return $Code }
        }
        return $Code
    }
}
