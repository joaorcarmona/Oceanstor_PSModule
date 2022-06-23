class OceanStorPortFC{
    [string]${Port Type}
    [string]${Port Id}
    [string]${Port Name}
    [string]${Parent Type}
    [string]${Parent Id}
    [string]${Location}
    [string]${health Status}
    [string]${Running Status}
    [string]${Logic Type}
    [string]${Operating Rate}
    [string]${Configured Speed}
    [string]${WWN}
    [string]${Working Mode}
    [string]${SFP Status}
    [string]${FC Configured Mode}
    [string]${FC Running Mode}
    [string]${Loss Signal Error}
    [string]${RX CHAR Error}
    [string]${Loss Sync Error}
    [string]${Link Fail Error}
    [string]${Collection Start}
    [string]${FLOGIN Latency}
    [string]${Max Port Speed}
    [string]${Port Switch}
    [string]${Light Status}
    [string]${Maximum Speed}
    [string]${CRC Error}
    [string]${EndSign Error}
    [string]${Host Initiators}

    OceanStorPortFC([array]$portReceived){

        switch ($portReceived.TYPE)
        {
            212 {$this.{Port Type} = "Fibre Channel"}
        }

        $this.{Port Id} = $portReceived.ID
        $this.{Port Name} = $portReceived.NAME

        switch ($portReceived.PARENTTYPE)
        {
            207 {$this.{Parent Type} = "controller"}
            209 {$this.{Parent Type} = "interface module"}
        }

        switch ($portReceived.HEALTHSTATUS)
        {
            0 {$this.{health Status} = "unknown"}
            1 {$this.{health Status} = "normal"}
            2 {$this.{health Status} = "faulty"}
            3 {$this.{health Status} = "about to fail"}
            9 {$this.{health Status} = "inconsistency"}
        }

        switch ($portReceived.RUNNINGSTATUS)
        {
            0 {$this.{Running Status} = "unknown"}
            1 {$this.{Running Status} = "normal"}
            2 {$this.{Running Status} = "running"}
            10 {$this.{Running Status} = "link up"}
            11 {$this.{Running Status} = "link down"}
        }

        switch ($portReceived.LOGICTYPE)
        {
            0 {$this.{Logic Type} = "host port/ service port"}
        }

        $this.{Operating Rate} = $portReceived.RUNSPEED
        $this.{Configured Speed} = $portReceived.CONFSPEED
        $this.{WWN} = $portReceived.WWN

        switch ($portReceived.INIORTGT)
        {
            2 {$this.{Working Mode} = "initiator"}
            3 {$this.{Working Mode} = "target"}
            4 {$this.{Working Mode} = "initiator and target"}
        }

        switch ($portReceived.SFPSTATUS)
        {
            0 {$this.{SFP Status} = "absent"}
            1 {$this.{SFP Status} = "offline"}
            2 {$this.{SFP Status} = "online"}
        }

        switch ($portReceived.FCCONFMODE)
        {
            0 {$this.{FC Configured Mode} = "fabric"}
            1 {$this.{FC Configured Mode} = "FC-AL"}
            2 {$this.{FC Configured Mode} = "P2P"}
            3 {$this.{FC Configured Mode} = "auto"}
            -1 {$this.{FC Configured Mode} = "incorrect"}
        }

        switch ($portReceived.FCRUNMODE)
        {
            0 {$this.{FC Running Mode} = "fabric"}
            1 {$this.{FC ConRunningfigured Mode} = "FC-AL"}
            2 {$this.{FC Running Mode} = "P2P"}
            3 {$this.{FC Running Mode} = "auto"}
            -1 {$this.{FC Running Mode} = "incorrect"}
        }

        $this.{Loss Signal Error} = $portReceived.LOSTSIGNALS
        $this.{RX CHAR Error} = $portReceived.BADCHARNUMBER
        $this.{Loss Sync Error} = $portReceived.LOSTSYNC
        $this.{Link Fail Error} = $portReceived.LINKFAIL
        $this.{Collection Start} = $portReceived.STARTTIME
        $this.{FLOGIN Latency} = $portReceived.FLOGINDELAYTIMES
        $this.{Max Port Speed} = $portReceived.MAXSUPPORTSPEEP

        switch ($portReceived.PORTSWITCH)
        {
            true {$this.{Port Switch} = "on"}
            false {$this.{Port Switch} = "off"}
        }

        switch ($portReceived.lightStatus)
        {
            0 {$this.{Light Status} = "off"}
            1 {$this.{Light Status} = "on"}
        }
        $this.{Maximum Speed} = $portReceived.MAXSPEED
        $this.{CRC Error} = $portReceived.BADCRCNUM
        $this.{EndSign Error} = $portReceived.endOfFrameErrors
        $this.{Host Initiators} = $portReceived.numberOfInitiators

    }

}