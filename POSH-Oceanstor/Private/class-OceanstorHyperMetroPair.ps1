class OceanstorHyperMetroPair {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]${Health Status}
    [string]${Health Status Code}
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Domain Id}
    [string]${Domain Name}
    [string]${Link Status}
    [string]${Link Status Code}
    [string]${Resource Type}
    [string]${Local Object Id}
    [string]${Local Object Name}
    [string]${Remote Object Id}
    [string]${Remote Object Name}
    [string]${Is Primary}
    [string]${Resource WWN}
    [string]${Recovery Policy}
    [string]${Local Data State}
    [string]${Is Isolation}
    [string]${Sync Left Time}
    [string]${HD Ring Id}
    [string]${vStore Pair Id}
    [string]${vStore Id}
    [string]${vStore Name}
    [string]${Config Status}
    [string]${Resource Role}

    OceanstorHyperMetroPair([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorHyperMetroPair]::GetString($Source, @('ID', 'id'))
        $this.{Health Status Code} = [OceanstorHyperMetroPair]::GetString($Source, @('HEALTHSTATUS'))
        $this.{Running Status Code} = [OceanstorHyperMetroPair]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Link Status Code} = [OceanstorHyperMetroPair]::GetString($Source, @('LINKSTATUS'))
        $this.{Health Status} = [OceanstorHyperMetroPair]::ConvertHealthStatus($this.{Health Status Code})
        $this.{Running Status} = [OceanstorHyperMetroPair]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Link Status} = [OceanstorHyperMetroPair]::ConvertLinkStatus($this.{Link Status Code})
        $this.{Domain Id} = [OceanstorHyperMetroPair]::GetString($Source, @('DOMAINID'))
        $this.{Domain Name} = [OceanstorHyperMetroPair]::GetString($Source, @('DOMAINNAME'))
        $this.{Resource Type} = [OceanstorHyperMetroPair]::GetString($Source, @('HCRESOURCETYPE'))
        $this.{Local Object Id} = [OceanstorHyperMetroPair]::GetString($Source, @('LOCALOBJID'))
        $this.{Local Object Name} = [OceanstorHyperMetroPair]::GetString($Source, @('LOCALOBJNAME'))
        $this.{Remote Object Id} = [OceanstorHyperMetroPair]::GetString($Source, @('REMOTEOBJID'))
        $this.{Remote Object Name} = [OceanstorHyperMetroPair]::GetString($Source, @('REMOTEOBJNAME'))
        $this.{Is Primary} = [OceanstorHyperMetroPair]::GetString($Source, @('ISPRIMARY'))
        $this.{Resource WWN} = [OceanstorHyperMetroPair]::GetString($Source, @('RESOURCEWWN'))
        $this.{Recovery Policy} = [OceanstorHyperMetroPair]::GetString($Source, @('RECOVERYPOLICY'))
        $this.{Local Data State} = [OceanstorHyperMetroPair]::GetString($Source, @('LOCALDATASTATE'))
        $this.{Is Isolation} = [OceanstorHyperMetroPair]::GetString($Source, @('ISISOLATION'))
        $this.{Sync Left Time} = [OceanstorHyperMetroPair]::GetString($Source, @('SYNCLEFTTIME'))
        $this.{HD Ring Id} = [OceanstorHyperMetroPair]::GetString($Source, @('HDRINGID'))
        $this.{vStore Pair Id} = [OceanstorHyperMetroPair]::GetString($Source, @('VSTOREPAIRID'))
        $this.{vStore Id} = [OceanstorHyperMetroPair]::GetString($Source, @('vstoreId'))
        $this.{vStore Name} = [OceanstorHyperMetroPair]::GetString($Source, @('vstoreName'))
        $this.{Config Status} = [OceanstorHyperMetroPair]::GetString($Source, @('CONFIGSTATUS'))
        $this.{Resource Role} = [OceanstorHyperMetroPair]::GetString($Source, @('resourceRole'))
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
        $value = [OceanstorHyperMetroPair]::GetValue($Source, $Names)
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
            '41' { return 'Suspended' }
            default { return $Code }
        }
        return $Code
    }

    static [string] ConvertLinkStatus([string]$Code) {
        switch ($Code) {
            '1' { return 'Normal' }
            '2' { return 'Faulty' }
            '10' { return 'Link Up' }
            '11' { return 'Link Down' }
            default { return $Code }
        }
        return $Code
    }
}
