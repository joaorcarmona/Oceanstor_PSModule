class OceanStorPortBond{
    hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
    [string]${Id}
    [string]${Name}
    [string]${Port Type}
    [string]${Health Status}
    [string]${Running Status}
    [string]${Ethernet Ports}
    [string]${MTU}
    [string]${Port Usage}
    [string]${Device Name}

    OceanStorPortBond ([array]$portReceived, [pscustomobject]$WebSession){
        $this.Session = $WebSession
		$this.WebSession = $WebSession

        switch ($portReceived.TYPE)
        {
            235 {$this.{Port Type} = "Bond Port"}
        }

        $this.{Id} = $portReceived.ID
        $this.{Name} = $portReceived.NAME

        switch ($portReceived.HEALTHSTATUS)
        {
            0 {$this.{Health Status} = "unknown"}
            1 {$this.{Health Status} = "normal"}
            2 {$this.{Health Status} = "faulty"}
            3 {$this.{Health Status} = "about to fail"}
            9 {$this.{Health Status} = "partially damaged"}
        }

        switch ($portReceived.RUNNINGSTATUS)
        {
            0 {$this.{Running Status} = "unknown"}
            1 {$this.{Running Status} = "normal"}
            2 {$this.{Running Status} = "running"}
            10 {$this.{Running Status} = "link up"}
            11 {$this.{Running Status} = "link down"}
        }

        # PORTIDLIST arrives as an OceanStor JSON-encoded string such as '["1211"]'
        # (or '[""]' when the bond has no members yet). Decode it the same way the
        # QoS-policy association lists are handled, so `Ethernet Ports` shows the
        # member port IDs plainly instead of raw brackets or a phantom empty entry.
        $this.{Ethernet Ports} = [OceanStorPortBond]::ParsePortIdList($portReceived.PORTIDLIST) -join ', '
        $this.{MTU} = $portReceived.MTU

        switch ($portReceived.USEDTYPE)
        {
            1 {$this.{Port Usage} = "used for VM"}
            2 {$this.{Port Usage} = "used for Storage"}
        }
        $this.{Device Name} = $portReceived.DEVICENAME

    }

    # OceanStor returns PORTIDLIST as a JSON-encoded string like '["1211","1212"]'
    # or, for an empty bond, '[""]'. Decode into a real string array and drop empty
    # entries so an empty bond yields @() instead of a phantom '' element. Values
    # already delivered as an array (e.g. unit-test mocks) pass through unchanged.
    static [string[]] ParsePortIdList([object]$Raw) {
        if ($null -eq $Raw) { return @() }
        $items = if ($Raw -is [string]) {
            try { @($Raw | ConvertFrom-Json) } catch { @($Raw) }
        }
        else { @($Raw) }
        return @($items | Where-Object { $null -ne $_ -and "$_".Trim() -ne '' })
    }

}


