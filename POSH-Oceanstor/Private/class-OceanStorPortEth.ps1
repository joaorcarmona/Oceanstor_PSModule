class OceanStorPortETH {
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
    [string]${End Sign Error}
    [string]${Host Initiators}
    [string]${Ethernet Ports}
    [string]${MTU}
    [string]${Port Usage}
    [string]${Device Name}
    [string]${Invalid DWORD}
    [string]${Inconsistency Error}
    [string]${Lost DWORD}
    [string]${PHY Failed RST}
    [string]${Current Id Peer Port}
    [string]${Suggested Id Peer Port}
    [string]${Mini SAS}
    [string]${Disk Enclosure WWN}
    [string]${Mac Address}
    [string]${Duplex Mode}
    [string]${Negotiation Mode}
    [string]${Bond Name}
    [string]${IPv4 Address}
    [string]${IPv4 Mask}
    [string]${IPv4 Gateway}
    [string]${IPv6 Address}
    [string]${IPv6 Mask}
    [string]${IPv6 Gateway}
    [string]${iSCSI Port Id}
    [string]${iSCSI Name}
    [string]${Packet Error}
    [string]${Packet Lost}
    [string]${Packet Overflowed}
    [string]${Port Speed}
    [string]${Port Vlan Id}
    [string]${Port Profile}
    [string]${Switching Plane Id}
    [string]${Switching Virtual Id}
    [string]${Connection Status}
    [string]${Port Bond Id}
    [string]${Device Name}
    [string]${Port Profile Usage}
    [string]${Owning Controller}
    [string]${Error CRC}
    [string]${Error Frame}
    [string]${Error Frame Lenght}
    [string]${Total Received Packets}
    [string]${Total Transmitted Packets}
    [string]${Total Received Bytes}
    [string]${Total Transmitted Bytes}
    [string]${Avg. Received Packets}
    [string]${Avg. Transmitted Packets}
    [string]${Avg. Received Bytes}
    [string]${Avg. Transmitted Bytes}
    [string]${Working Rate}
    [string]${Port Function}

    OceanStorPortETH ([array]$portReceived)
    {
        switch ($portReceived.TYPE)
        {
            213 {$this.{Port Type} = "Ethernet Port"}
        }

        $this.{Port Id} = $portReceived.ID
        $this.{Port Name} = $portReceived.NAME
        $this.{Location} = $portReceived.LOCATION

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
            0 {$this.{Logic Type} = "host port/service port"}
            2 {$this.{Logic Type} = "management port"}
            3 {$this.{Logic Type} = "internal port"}
            4 {$this.{Logic Type} = "maintenance port"}
            5 {$this.{Logic Type} = "management/Service port"}
            6 {$this.{Logic Type} = "maintenance/Service port"}
            11 {$this.{Logic Type} = "IP Scale-out interconnect port"}
        }

        $this.{Mac Address} = $portReceived.MACADDRESS

        switch ($portReceived.INIORTGT)
        {
            2 {$this.{Working Mode} = "initiator"}
            3 {$this.{Working Mode} = "target"}
            4 {$this.{Working Mode} = "initiator and target"}
        }

        switch ($portReceived.ETHDUPLEX)
        {
            1 {$this.{Duplex Mode} = "half duplex (HD)"}
            1 {$this.{Duplex Mode} = "full duplex (FD)"}
            1 {$this.{Duplex Mode} = "auto-negotiation"}
        }

        switch ($portReceived.ETHNEGOTIATE)
        {
            1 {$this.{Negotiation Mode} = "HD"}
            2 {$this.{Negotiation Mode} = "FD"}
            3 {$this.{Negotiation Mode} = "auto-negotiation"}
        }

        $this.{MTU} = $portReceived.MTU
        $this.{Bond Name} = $portReceived.BONDNAME
        $this.{IPv4 Address} = $portReceived.IPV4ADDR
        $this.{IPv4 Mask} = $portReceived.IPV4MASK
        $this.{IPv4 Gateway} = $portReceived.IPv4GATEWAY
        $this.{IPv6 Address} = $portReceived.IPV6ADDR
        $this.{IPv6 Mask} = $portReceived.IPV6MASK
        $this.{IPv6 Gateway} = $portReceived.IPv6GATEWAY
        $this.{iSCSI Port Id} = $portReceived.ISCSITCPPORT
        $this.{iSCSI Name} = $portReceived.ISCSINAME
        $this.{Packet Error} = $portReceived.ERRORPACKETS
        $this.{Packet Lost} = $portReceived.LOSTPACKETS
        $this.{Packet Overflowed} = $portReceived.OVERFLOWEDPACKETS
        $this.{Collection Start} = $portReceived.STARTTIME
        $this.{Port Speed} = $portReceived.SPEED
        $this.{Port Vlan Id} = $portReceived.vlan

        switch ($portReceived.selectType)
        {
            0 {$this.{Port Profile} = "host port/service port"}
            2 {$this.{Port Profile} = "management port"}
            4 {$this.{Port Profile} = "maintenance port"}
        }

        $this.{Switching Plane Id} = $portReceived.zoneId
        $this.{Switching Virtual Id} = $portReceived.dswId

        switch ($portReceived.dswLinkRight)
        {
            0 {$this.{Connection Status} = "incorrect"}
            1 {$this.{Connection Status} = "correct"}
        }

        switch ($portReceived.PORTSWITCH)
        {
            true {$this.{Port Switch} = "on"}
            false {$this.{Port Switch} = "off"}
        }

        $this.{Port Bond Id} = $portReceived.BONID
        $this.{Device Name} = $portReceived.DEVICENAME

        switch ($portReceived.lightStatus)
        {
            0 {$this.{Light Status} = "off"}
            1 {$this.{Light Status} = "on"}
        }

        switch ($portReceived.USEDTYPE)
        {
            1 {$this.{Port Usage} = "Applicable to Storage OS"}
            2 {$this.{Port Usage} = "Applicable to VM System"}
        }

        switch ($portReceived.portUsage)
        {
            1 {$this.{Port Profile Usage} = "service"}
            2 {$this.{Port Profile Usage} = "management"}
            3 {$this.{Port Profile Usage} = "maintenance"}
        }

        $this.{Owning Controller} = $portReceived.OWNINGCONTROLLER
        $this.{Error CRC} = $portReceived.crcErrors
        $this.{Error Frame} = $portReceived.frameErrrors
        $this.{Error Frame Lenght} = $portReceived.frameLengthErrors
        $this.{Total Received Packets} = $portReceived.totalReceivedPackets
        $this.{Total Transmitted Packets} = $portReceived.totalTransmittedPackets
        $this.{Total Received Bytes} = $portReceived.totalReceivedBytes
        $this.{Total Transmitted Bytes} = $portReceived.totalTransmittedBytes
        $this.{Avg. Received Packets} = $portReceived.receivedPacketsPerSec
        $this.{Avg. Transmitted Packets} = $portReceived.transmittedPacketsPerSec
        $this.{Avg. Received Bytes} = $portReceived.receivedBytesPerSec
        $this.{Avg. Transmitted Bytes} = $portReceived.transmittedBytesPerSec
        $this.{Working Rate} = $portReceived.maxSpeed

        switch ($portReceived.portFilter)
        {
            0 {$this.{Port Function} = "Used to configured IP Addesses"}
            1 {$this.{Port Function} = "Used to create LIFs"}
            2 {$this.{Port Function} = "Used to create VLANs"}
            3 {$this.{Port Function} = "Used to create BONDs"}
            4 {$this.{Port Function} = "Port added to a custom failover-group"}
            5 {$this.{Port Function} = "Port added to a VM"}
            6 {$this.{Port Function} = "Port added to an arbitration link"}
        }

        $this.{Host Initiators} = $portReceived.numberOfInitiators
    }
}