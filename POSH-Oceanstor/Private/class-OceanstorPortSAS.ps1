class OceanstorPortSAS{
    [string]${Id}
    [string]${Name}
    [string]${Port Type}
    [string]${Parent Type}
    [string]${Parent Id}
    [string]${Port Location}
    [string]${health Status}
    [string]${Running Status}
    [string]${Logic Type}
    [string]${Operating Rate}
    [string]${WWN}
    [string]${Working Mote}
    [string]${Port Switch}
    [string]${Invalid DWORD}
    [string]${Inconsistency Error}
    [string]${Lost DWORD}
    [string]${PHY Failed RST}
    [string]${Collection Start}
    [string]${Current Id Peer Port}
    [string]${Suggested Id Peer Port}
    [string]${Light Status}
    [string]${Mini SAS}
    [string]${Disk Enclosure WWN}
    [string]${Maximum Speed}

    OceanstorPortSAS ([array]$portReceived)
    {
        switch ($portReceived.TYPE)
        {
            214 {$this.{Port Type} = "SAS Port"}
        }

        $this.{Port Id} = $portReceived.ID
        $this.{Port Name} = $portReceived.NAME
        $this.{Parent Type} = $portReceived.PARENTTYPE
        $this.{Parent Id} = $portReceived.PARENTID
        $this.{Port Location} = $portReceived.LOCATION

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
            1 {$this.{Logic Type} = "expansion port"}
        }

        $this.{Operating Rate} = $portReceived.RUNSPEED
        $this.{WWN} = $portReceived.WWN

        switch ($portReceived.INIORTGT)
        {
            2 {$this.{Working Mote} = "initiator"}
            3 {$this.{Working Mote} = "target"}
            4 {$this.{Working Mote} = "initiator and target"}
        }

        switch ($portReceived.PORTSWITCH)
        {
            true {$this.{Port Switch} = "open"}
            false {$this.{Port Switch} = "close"}
        }

        $this.{Invalid DWORD} = $portReceived.INVALIDDWORD
        $this.{Inconsistency Error} = $portReceived.DISPARITYERROR
        $this.{Lost DWORD} = $portReceived.LOSSDWORD
        $this.{PHY Failed RST} = $portReceived.PHYRESETERRORS
        $this.{Collection Start} = $portReceived.STARTTIME
        $this.{Current Id Peer Port} = $portReceived.CURRENT_PEER_PORT_ID
        $this.{Suggested Id Peer Port} = $portReceived.SUGGEST_PEER_PORT_ID

        switch ($portReceived.LIGHTSTATUS)
        {
            1 {$this.{Light Status} = "on"}
            2 {$this.{Light Status} = "off"}
        }

        switch ($portReceived.ISMINISAS)
        {
            true {$this.{Mini SAS} = "yes"}
            false {$this.{Mini SAS} = "no"}
        }

        $this.{Disk Enclosure WWN} = $portReceived.ENCLOSURE_WWN_LIST
        $this.{Maximum Speed} = $portReceived.MAXSPEED

    }
}