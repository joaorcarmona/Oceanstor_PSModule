class OceanStorFailoverGroupMember {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}
    [string]${Id}
    [string]${Name}
    [string]${Member Type}
    [string]${Running Status}
    [string]${Failover Group Id}

    OceanStorFailoverGroupMember ([object]$memberReceived, [string]$failoverGroupId, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $this.Id = $memberReceived.ID
        $this.Name = $memberReceived.NAME
        $this.'Failover Group Id' = $failoverGroupId

        switch ($memberReceived.TYPE) {
            213 { $this.'Member Type' = 'Ethernet Port' }
            235 { $this.'Member Type' = 'Bond Port' }
            280 { $this.'Member Type' = 'VLAN' }
            default { $this.'Member Type' = $memberReceived.TYPE }
        }

        switch ($memberReceived.RUNNINGSTATUS) {
            0 { $this.'Running Status' = 'Unknown' }
            1 { $this.'Running Status' = 'Normal' }
            2 { $this.'Running Status' = 'Running' }
            10 { $this.'Running Status' = 'Link Up' }
            11 { $this.'Running Status' = 'Link Down' }
            33 { $this.'Running Status' = 'To Be Recovered' }
            53 { $this.'Running Status' = 'Initializing' }
            default { $this.'Running Status' = $memberReceived.RUNNINGSTATUS }
        }
    }
}
