class OceanstorHyperMetroConsistencyGroup {
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
    [string]$Speed
    [string]${Priority Site}
    [string]${Recovery Policy}
    [string]${Domain Id}
    [string]${Domain Name}
    [string]${Resource Type}
    [string]${Local Protection Group Id}
    [string]${Local Protection Group Name}
    [string]${Remote Protection Group Id}
    [string]${Remote Protection Group Name}

    OceanstorHyperMetroConsistencyGroup([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('NAME', 'name'))
        $this.Description = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('DESCRIPTION', 'description'))
        $this.{Health Status Code} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('HEALTHSTATUS'))
        $this.{Running Status Code} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('RUNNINGSTATUS'))
        $this.{Health Status} = [OceanstorHyperMetroConsistencyGroup]::ConvertHealthStatus($this.{Health Status Code})
        $this.{Running Status} = [OceanstorHyperMetroConsistencyGroup]::ConvertRunningStatus($this.{Running Status Code})
        $this.Speed = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('SPEED'))
        $this.{Priority Site} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('PRIORITYSTATION'))
        $this.{Recovery Policy} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('RECOVERYPOLICY'))
        $this.{Domain Id} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('DOMAINID'))
        $this.{Domain Name} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('DOMAINNAME'))
        $this.{Resource Type} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('RESOURCETYPE'))
        $this.{Local Protection Group Id} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('localPgId'))
        $this.{Local Protection Group Name} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('localPgName'))
        $this.{Remote Protection Group Id} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('remotePgId'))
        $this.{Remote Protection Group Name} = [OceanstorHyperMetroConsistencyGroup]::GetString($Source, @('remotePgName'))
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
        $value = [OceanstorHyperMetroConsistencyGroup]::GetValue($Source, $Names)
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
}
