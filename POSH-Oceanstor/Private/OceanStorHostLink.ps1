class OceanStorHostLink
{
    [string]${Id}
    [string]${Initiator Id}
    [string]${Host Id}
    [string]${Host Name}
    [string]${Initiator Node WWN}
    [string]${Initiator Port WWN}
    [string]${Initiator Type}
    [string]${Controller ID}
    [string]${Health Status}
    [string]${Running Status}
    [string]${Target Id}
    [string]${Target Node WWN}
    [string]${Target Port WWN}
    [string]${Target Type}
    [string]${Type}
    [string]${Ultrapath Version}

    OceanStorHostLink([array]$linkReceived)
    {
        $this.{Controller ID} = $linkReceived.CTRL_ID
        switch($linkReceived.HEALTHSTATUS)
		{
			1 {$this.{Health Status}  = "normal"}
            2 {$this.{Health Status}  = "faulty"}
		}

        $this.{Id} = $linkReceived.ID
        $this.{Initiator Id} = $linkReceived.INITIATOR_ID
        $this.{Initiator Node WWN} = $linkReceived.INITIATOR_NODE_WWN
        $this.{Initiator Port WWN} = $linkReceived.INITIATOR_PORT_WWN
        $this.{Initiator Type} = $linkReceived.INITIATOR_TYPE
        $this.{Host Id} = $linkReceived.PARENTID
        $this.{Host Name} = $linkReceived.PARENTNAME

        switch($linkReceived.RUNNINGSTATUS)
		{
			10 {$this.{Running Status}  = "Link UP"}
            11 {$this.{Running Status}  = "Link DOWN"}
            27 {$this.{Running Status}  = "Online"}
            31 {$this.{Running Status}  = "Disabled"}
            101 {$this.{Running Status}  = "Connecting"}
		}
        $this.{Target Id} = $linkReceived.TARGET_ID
        $this.{Target Node WWN} = $linkReceived.TARGET_NODE_WWN
        $this.{Target Port WWN} = $linkReceived.TARGET_PORT_WWN

        switch($linkReceived.TARGET_TYPE)
		{
            212 {$this.{Target Type}  = "Fibre Channel Port"}
			213 {$this.{Target Type}  = "Ethernet Port"}
		}

        switch($linkReceived.TYPE)
		{
			255 {$this.{Type}  = "Host Link"}
		}
        $this.{Ultrapath Version} = $linkReceived.ULTRAPATHVERSION
    }
}