class OceanstorFileHyperMetroDomain {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Service Status}
    [string]${Service Status Code}
    [string]$Role
    [string]${Config Role}
    [string]${Domain Type}
    [string]${Arbitration Type}
    [string]${Quorum Server Name}
    [string]${Remote Devices}
    [string]${Recovery Policy}
    [string]${Work Mode}
    [string]${Logic Port Status}

    OceanstorFileHyperMetroDomain([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorFileHyperMetroDomain]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanstorFileHyperMetroDomain]::GetString($Source, @('NAME', 'name'))
        $this.Description = [OceanstorFileHyperMetroDomain]::GetString($Source, @('DESCRIPTION'))
        $this.{Running Status Code} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Running Status} = [OceanstorFileHyperMetroDomain]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Service Status Code} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('SERVICESTATUS'))
        $this.{Service Status} = [OceanstorFileHyperMetroDomain]::ConvertServiceStatus($this.{Service Status Code})
        $this.Role = [OceanstorFileHyperMetroDomain]::GetString($Source, @('ROLE'))
        $this.{Config Role} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('CONFIGROLE'))
        $this.{Domain Type} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('DOMAINTYPE', 'DOAINTYPE'))
        $this.{Arbitration Type} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('CPTYPE'))
        $this.{Quorum Server Name} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('CPSNAME'))
        $this.{Remote Devices} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('REMOTEDEVICES'))
        $this.{Recovery Policy} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('mscRecoverPolicy'))
        $this.{Work Mode} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('workMode'))
        $this.{Logic Port Status} = [OceanstorFileHyperMetroDomain]::GetString($Source, @('logicPortStatus'))
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
        $value = [OceanstorFileHyperMetroDomain]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    static [string] ConvertRunningStatus([string]$Code) {
        switch ($Code) {
            '0' { return 'Normal' }
            '1' { return 'Recovering' }
            '2' { return 'Faulty' }
            '3' { return 'Split' }
            '4' { return 'ForceStarted' }
            '5' { return 'Invalid' }
            '33' { return 'ToBeRecovered' }
            '35' { return 'Invalid' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertServiceStatus([string]$Code) {
        switch ($Code) {
            '0' { return 'Active' }
            '1' { return 'Passive' }
            default { return $Code }
        }
        return $Code
    }
}
