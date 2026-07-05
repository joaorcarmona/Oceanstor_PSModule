class OceanstorRemoteDevice {
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
    [string]${Array Type}
    [string]${Array Type Code}
    [string]${Serial Number}
    [string]$Vendor
    [string]$WWN
    [string]${Link Count}
    [string]${FC Link Count}
    [string]${iSCSI Link Count}
    [string]${IP Link Count}
    [string]${Remote Replication Port Group Id}
    [string]${Local Replication Port Group Id}

    OceanstorRemoteDevice([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorRemoteDevice]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanstorRemoteDevice]::GetString($Source, @('NAME', 'name'))
        $this.Description = [OceanstorRemoteDevice]::GetString($Source, @('DESCRIPTION', 'description'))
        $this.{Health Status Code} = [OceanstorRemoteDevice]::GetString($Source, @('HEALTHSTATUS', 'healthStatus'))
        $this.{Running Status Code} = [OceanstorRemoteDevice]::GetString($Source, @('RUNNINGSTATUS', 'runningStatus'))
        $this.{Array Type Code} = [OceanstorRemoteDevice]::GetString($Source, @('ARRAYTYPE', 'arrayType'))
        $this.{Health Status} = [OceanstorRemoteDevice]::ConvertHealthStatus($this.{Health Status Code})
        $this.{Running Status} = [OceanstorRemoteDevice]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Array Type} = [OceanstorRemoteDevice]::ConvertArrayType($this.{Array Type Code})
        $this.{Serial Number} = [OceanstorRemoteDevice]::GetString($Source, @('SN', 'DEVICESN'))
        $this.Vendor = [OceanstorRemoteDevice]::GetString($Source, @('VENDOR'))
        $this.WWN = [OceanstorRemoteDevice]::GetString($Source, @('WWN'))
        $this.{Link Count} = [OceanstorRemoteDevice]::GetString($Source, @('LINKNUM'))
        $this.{FC Link Count} = [OceanstorRemoteDevice]::GetString($Source, @('FCLINKNUM'))
        $this.{iSCSI Link Count} = [OceanstorRemoteDevice]::GetString($Source, @('ISCSILINKNUM'))
        $this.{IP Link Count} = [OceanstorRemoteDevice]::GetString($Source, @('IPLINKNUM'))
        $this.{Remote Replication Port Group Id} = [OceanstorRemoteDevice]::GetString($Source, @('REMOTE_REP_PORT_GROUP_ID'))
        $this.{Local Replication Port Group Id} = [OceanstorRemoteDevice]::GetString($Source, @('LOCAL_REP_PORT_GROUP_ID'))
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
        $value = [OceanstorRemoteDevice]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    static [string] ConvertHealthStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '2' { return 'Faulty' }
            '14' { return 'Invalid' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertRunningStatus([string]$Code) {
        switch ($Code) {
            '10' { return 'Link Up' }
            '11' { return 'Link Down' }
            '31' { return 'Disabled' }
            '101' { return 'Connecting' }
            '118' { return 'Air Gap Link Down' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertArrayType([string]$Code) {
        switch ($Code) {
            '1' { return 'Replication Device' }
            '2' { return 'Heterogeneous Device' }
            '3' { return 'Unknown Device' }
            '4' { return 'Cloud Replication Device' }
            default { return $Code }
        }
        return $Code
    }
}
