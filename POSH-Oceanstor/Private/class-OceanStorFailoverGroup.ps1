class OceanStorFailoverGroup {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}
    [string]${Id}
    [string]${Name}
    [string]${Description}
    [string]${Type}
    [string]${Failover Group Type}
    [string]${Service Type}
    [string]${IP Type}

    OceanStorFailoverGroup ([object]$groupReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Id = $groupReceived.ID
        $this.Name = $groupReceived.NAME
        $this.Description = $groupReceived.DESCRIPTION

        switch ($groupReceived.TYPE) {
            289 { $this.Type = 'Failover Group' }
            default { $this.Type = $groupReceived.TYPE }
        }

        switch ($groupReceived.FAILOVERGROUPTYPE) {
            1 { $this.{Failover Group Type} = 'System' }
            2 { $this.{Failover Group Type} = 'VLAN' }
            3 { $this.{Failover Group Type} = 'Customized' }
            default { $this.{Failover Group Type} = $groupReceived.FAILOVERGROUPTYPE }
        }

        switch ($groupReceived.failoverGroupServiceType) {
            0 { $this.'Service Type' = 'NAS' }
            3 { $this.'Service Type' = 'BGP' }
            default { $this.'Service Type' = $groupReceived.failoverGroupServiceType }
        }

        switch ($groupReceived.failoverGroupIpType) {
            0 { $this.'IP Type' = 'IPv4' }
            1 { $this.'IP Type' = 'IPv6' }
            default { $this.'IP Type' = $groupReceived.failoverGroupIpType }
        }
    }
}
