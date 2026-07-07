class OceanStorQuorumServer {
    hidden [pscustomobject]$Session
    hidden [pscustomobject]$WebSession
    hidden [object]$Raw

    [string]$Id
    [string]$Name
    [string]$Description
    [string]${Running Status}
    [string]${Running Status Code}
    [string]${Primary IP Address}
    [string]${Primary Port}
    [string]${Secondary IP Address}
    [string]${Secondary Port}
    [string]${Device SN}
    [string]$Username

    OceanStorQuorumServer([object]$Source, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Raw = $Source
        $this.Id = [OceanStorQuorumServer]::GetString($Source, @('ID', 'id'))
        $this.Name = [OceanStorQuorumServer]::GetString($Source, @('NAME', 'name'))
        $this.Description = [OceanStorQuorumServer]::GetString($Source, @('DESCRIPTION', 'description'))
        $this.{Running Status Code} = [OceanStorQuorumServer]::GetString($Source, @('RUNNINGSTATUS', 'runningStatus'))
        $this.{Running Status} = [OceanStorQuorumServer]::ConvertRunningStatus($this.{Running Status Code})
        $this.{Primary IP Address} = [OceanStorQuorumServer]::GetString($Source, @('SERVERIPA'))
        $this.{Primary Port} = [OceanStorQuorumServer]::GetString($Source, @('SERVERPORTA'))
        $this.{Secondary IP Address} = [OceanStorQuorumServer]::GetString($Source, @('SERVERIPB'))
        $this.{Secondary Port} = [OceanStorQuorumServer]::GetString($Source, @('SERVERPORTB'))
        $this.{Device SN} = [OceanStorQuorumServer]::GetString($Source, @('DEVICESN'))
        $this.Username = [OceanStorQuorumServer]::GetString($Source, @('USERNAME'))
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
        $value = [OceanStorQuorumServer]::GetValue($Source, $Names)
        if ($null -eq $value) { return $null }
        return [string]$value
    }

    # RUNNINGSTATUS enum per OceanStor Dorado 6.1.6 REST Interface Reference
    # section 4.9.8 (quorum_server): 27 = online, 28 = offline.
    static [string] ConvertRunningStatus([string]$Code) {
        switch ($Code) {
            '27' { return 'Online' }
            '28' { return 'Offline' }
            default { return $Code }
        }
        return $Code
    }
}
