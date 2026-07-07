class OceanstorHyperMetroDomain {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Domain Type}
    [string]${Domain Type Code}
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Arbitration Type}
    [string]${Arbitration Type Code}
    [string]${Quorum Server Id}
    [string]${Quorum Server Name}
    [string]${Standby Quorum Server Id}
    [string]${Standby Quorum Server Name}
    [object]${Remote Devices}

    OceanstorHyperMetroDomain([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorHyperMetroDomain]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanstorHyperMetroDomain]::GetString($Source, @('NAME', 'name'))
        $this.Description = [OceanstorHyperMetroDomain]::GetString($Source, @('DESCRIPTION', 'description'))
        $this.{Domain Type Code} = [OceanstorHyperMetroDomain]::GetString($Source, @('DOMAINTYPE'))
        $this.{Running Status Code} = [OceanstorHyperMetroDomain]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Arbitration Type Code} = [OceanstorHyperMetroDomain]::GetString($Source, @('CPTYPE'))
        $this.{Domain Type} = [OceanstorHyperMetroDomain]::ConvertDomainType($this.{Domain Type Code})
        $this.{Running Status} = [OceanstorHyperMetroDomain]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Arbitration Type} = [OceanstorHyperMetroDomain]::ConvertArbitrationType($this.{Arbitration Type Code})
        $this.{Quorum Server Id} = [OceanstorHyperMetroDomain]::GetString($Source, @('CPSID'))
        $this.{Quorum Server Name} = [OceanstorHyperMetroDomain]::GetString($Source, @('CPSNAME'))
        $this.{Standby Quorum Server Id} = [OceanstorHyperMetroDomain]::GetString($Source, @('STANDBYCPSID'))
        $this.{Standby Quorum Server Name} = [OceanstorHyperMetroDomain]::GetString($Source, @('STANDBYCPSNAME'))
        $this.{Remote Devices} = [OceanstorHyperMetroDomain]::GetValue($Source, @('REMOTEDEVICES'))
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
        $value = [OceanstorHyperMetroDomain]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    static [string] ConvertDomainType([string]$Code) {
        switch ($Code) {
            '0' { return 'SAN' }
            '1' { return 'NAS' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertRunningStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '10' { return 'Link Up' }
            '11' { return 'Link Down' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertArbitrationType([string]$Code) {
        switch ($Code) {
            '1' { return 'Static Priority' }
            '2' { return 'Quorum Server' }
            default { return $Code }
        }
        return $Code
    }
}
