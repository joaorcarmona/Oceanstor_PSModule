class OceanStorPortBond{
    [string]${Port Type}
    [string]${Port Id}
    [string]${Port Name}
    [string]${health Status}
    [string]${Running Status}
    [string]${Ethernet Ports}
    [string]${MTU}
    [string]${Port Usage}
    [string]${Device Name}

    OceanStorPortBond ([array]$portReceived){

        switch ($portReceived.TYPE)
        {
            235 {$this.{Port Type} = "Bond Port"}
        }

        $this.{Port Id} = $portReceived.ID
        $this.{Port Name} = $portReceived.NAME

        switch ($portReceived.HEALTHSTATUS)
        {
            0 {$this.{health Status} = "unknown"}
            1 {$this.{health Status} = "normal"}
            2 {$this.{health Status} = "faulty"}
            3 {$this.{health Status} = "about to fail"}
            9 {$this.{health Status} = "partially damaged"}
        }

        switch ($portReceived.RUNNINGSTATUS)
        {
            0 {$this.{Running Status} = "unknown"}
            1 {$this.{Running Status} = "normal"}
            2 {$this.{Running Status} = "running"}
            10 {$this.{Running Status} = "link up"}
            11 {$this.{Running Status} = "link down"}
        }

        $this.{Ethernet Ports} = $portReceived.PORTIDLIST
        $this.{MTU} = $portReceived.MTU

        switch ($portReceived.USEDTYPE)
        {
            1 {$this.{Port Usage} = "used for VM"}
            2 {$this.{Port Usage} = "used for Storage"}
        }
        $this.{Device Name} = $portReceived.DEVICENAME

    }

}