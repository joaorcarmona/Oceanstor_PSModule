class OceanStorvLan
{
    #Define properties
    [string]$Id
    [string]${Name}
    [string]${Type}
    [string]${Vlan Tag Id}
    [string]${Port Type}
    [string]${Port Id}
    [string]${Port Name}
    [string]${Running Status}
    [string]${MTU}

    OceanStorvLan ([array]$vlanReceived,[pscustomobject]$webSession)
    {
        switch ($vlanReceived.TYPE)
        {
            280 {$this.Type = "VLAN"}
        }

        $this.Id = $vlanReceived.ID
        $this.{Name} = $vlanReceived.Name
        $this.{Vlan Tag Id} = $vlanReceived.TAG

        switch ($vlanReceived.PORTTYPE)
        {
            1 {$this.{Port Type} = "ETH Port"}
            7 {$this.{Port Type} = "Bond Port"}
        }

        $this.{Port Id} = $vlanReceived.PORTID
        #TODO - create function to retrieve port Name by ID
        #$this.{Port Name} = get-DMPortName -WebSession $webSession

        switch($vlanReceived.RUNNINGSTATUS)
		{
			0 {$this.{Running Status} = "unknown"}
			1 {$this.{Running Status} = "Normal"}
			2 {$this.{Running Status} = "running"}
			10 {$this.{Running Status} = "link up"}
			11 {$this.{Running Status} = "link down"}
			53 {$this.{Running Status} = "initializing"}
		}

        $this.MTU = $vlanReceived.MTU
    }



}