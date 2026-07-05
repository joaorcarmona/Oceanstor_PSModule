class OceanstorRemoteLun {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]$Name
    [string]${Remote Lun Id}
    [string]${Remote Lun WWN}
    [string]${Remote Device Id}
    [string]${Remote Device Name}
    [string]${Remote Device SN}
    [string]${Health Status}
    [string]${Health Status Code}
    [string]$Capacity
    [string]${Capacity Bytes}
    [string]${Array Type}
    [string]${Array Type Code}
    [string]$Used
    [string]$Vendor
    [string]$Model

    OceanstorRemoteLun([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorRemoteLun]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanstorRemoteLun]::GetString($Source, @('NAME', 'name'))
        $this.{Remote Lun Id} = [OceanstorRemoteLun]::GetString($Source, @('LUNID'))
        $this.{Remote Lun WWN} = [OceanstorRemoteLun]::GetString($Source, @('LUNWWN'))
        $this.{Remote Device Id} = [OceanstorRemoteLun]::GetString($Source, @('DEVICEID', 'rmtDeviceId'))
        $this.{Remote Device Name} = [OceanstorRemoteLun]::GetString($Source, @('DEVICENAME'))
        $this.{Remote Device SN} = [OceanstorRemoteLun]::GetString($Source, @('DEVICESN'))
        $this.{Health Status Code} = [OceanstorRemoteLun]::GetString($Source, @('HEALTHSTATUS'))
        $this.{Health Status} = [OceanstorRemoteLun]::ConvertHealthStatus($this.{Health Status Code})
        $this.Capacity = [OceanstorRemoteLun]::GetString($Source, @('CAPACITY', 'capacity'))
        $this.{Capacity Bytes} = [OceanstorRemoteLun]::GetString($Source, @('CAPACITYBYTE'))
        $this.{Array Type Code} = [OceanstorRemoteLun]::GetString($Source, @('ARRAYTYPE'))
        $this.{Array Type} = [OceanstorRemoteLun]::ConvertArrayType($this.{Array Type Code})
        $this.Used = [OceanstorRemoteLun]::GetString($Source, @('USED'))
        $this.Vendor = [OceanstorRemoteLun]::GetString($Source, @('VENDOR'))
        $this.Model = [OceanstorRemoteLun]::GetString($Source, @('MODEL'))
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
        $value = [OceanstorRemoteLun]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    static [string] ConvertHealthStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '2' { return 'Faulty' }
            '15' { return 'Write Protected' }
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
