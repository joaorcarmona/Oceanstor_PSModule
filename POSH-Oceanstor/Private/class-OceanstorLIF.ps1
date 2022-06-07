class OceanStorLIF
{
    #Define Proerties
    [string]${Address Family}
    [string]${Can Failover}
    [string]${Current Node Id}
    [string]${Current Port Id}
    [string]${Current Port Name}
    [string]${Current Port Type}
    [string]${Failback Mode}
    [string]${Failover Group Id}
    [string]${Failover Group Name}
    [string]${Home Node Id}
    [string]${Home Port Id}
    [string]${Home Port Name}
    [string]${Home Port Type}
    [string]${Id}
    [string]${IPv4 Address}
    [string]${IPv4 Gateway}
    [string]${IPv4 Mask}
    [string]${IPv6 Address}
    [string]${IPv6 Gateway}
    [string]${IPv6 Mask}
    [string]${Is Private}
    [string]${Management Access}
    [string]${LIF Name}
    [string]${Operational Status}
    [string]${Role}
    [string]${Running Status}
    [string]${Support Protocol}
    [string]${LIF Type}
    [string]${ddns Status}
    [string]${DNS Zone Name}
    [string]${Listen Dns Queries}
    [string]${vStore Id}
    [string]${vStore Name}

    #Constructor
    OceanStorLIF ([array]$lifReceived)
    {
        switch ($lifReceived.ADDRESSFAMILY)
        {
            0 {$this.{Address Family} = "IPv4"}
            1 {$this.{Address Family} = "IPv6"}
        }

        switch ($lifReceived.CANFAILOVER)
        {
            true {$this.{Can Failover} = $true}
            false {$this.{Can Failover} = $false}
        }

        $this.{Current Node Id} = $lifReceived.CURRENTNODEID
        $this.{Current Port Id} = $lifReceived.CURRENTPORTID
        $this.{Current Port Name} = $lifReceived.CURRENTPORTNAME

        switch ($lifReceived.CURRENTPORTTYPE)
        {
            1 {$this.{Current Port Type} = "Ethernet Port"}
            7 {$this.{Current Port Type} = "Bond"}
            8 {$this.{Current Port Type} = "VLAN"}
        }

        switch ($lifReceived.FAILBACKMODE)
        {
            1 {$this.{Failback Mode} = "manual"}
            2 {$this.{Failback Mode} = "auto"}
        }

        $this.{Failover Group Id} = $lifReceived.FAILOVERGROUPID
        $this.{Failover Group Name} = $lifReceived.FAILOVERGROUPNAME
        $this.{Home Node Id} = $lifReceived.HOMENODEID
        $this.{Home Port Id} = $lifReceived.HOMEPORTID
        $this.{Home Port Name} = $lifReceived.HOMEPORTNAME

        switch ($lifReceived.HOMEPORTTYPE)
        {
            1 {$this.{Home Port Type} = "Ethernet Port"}
            7 {$this.{Home Port Type} = "Bond"}
            8 {$this.{Home Port Type} = "VLAN"}
        }

        $this.{Id} = $lifReceived.ID
        $this.{IPv4 Address} = $lifReceived.IPV4ADDR
        $this.{IPv4 Gateway} = $lifReceived.IPV4GATEWAY
        $this.{IPv4 Mask} = $lifReceived.IPV4MASK
        $this.{IPv6 Address} = $lifReceived.IPV6ADDR
        $this.{IPv6 Gateway} = $lifReceived.IPV6GATEWAY
        $this.{IPv6 Mask} = $lifReceived.IPV6MASK

        switch ($lifReceived.ISPRIVATE)
        {
            true {$this.{Is Private} = "not configurable"}
            false {$this.{Is Private} = "configurable"}
        }

        $this.{Management Access} = $lifReceived.MANAGEMENTACCESS
        $this.{LIF Name} = $lifReceived.NAME

        switch ($lifReceived.OPERATIONALSTATUS)
        {
            0 {$this.{Operational Status} = "Activated"}
            1 {$this.{Operational Status} = "Not Activated"}
        }

        switch ($lifReceived.ROLE)
        {
            1 {$this.{Role} = "Management"}
            2 {$this.{Role} = "Service"}
            3 {$this.{Role} = "Management + Service"}
        }

        switch ($lifReceived.RUNNINGSTATUS)
        {
            0 {$this.{Running Status} = "Unknown"}
            1 {$this.{Running Status} = "Normal"}
            2 {$this.{Running Status} = "Running"}
            10 {$this.{Running Status} = "Link Up"}
            11 {$this.{Running Status} = "Link Down"}
            53 {$this.{Running Status} = "Initializing"}
        }

        switch ($lifReceived.SUPPORTPROTOCOL)
        {
            0 {$this.{Support Protocol} = "NONE"}
            1 {$this.{Support Protocol} = "NFS"}
            2 {$this.{Support Protocol} = "CIFS"}
            3 {$this.{Support Protocol} = "NFS+CIFS"}
            4 {$this.{Support Protocol} = "iSCSI"}
            8 {$this.{Support Protocol} = "FC/FCoE"}
        }

        $this.{LIF Type} = $lifReceived.TYPE

        switch ($lifReceived.ddnsStatus)
        {
            0 {$this.{ddns Status} = "INVALID"}
            1 {$this.{ddns Status} = "Enabled"}
            2 {$this.{ddns Status} = "Disabled"}
        }

        $this.{DNS Zone Name} = $lifReceived.dnsZoneName

        switch ($lifReceived.listenDnsQueryEnabled)
        {
            0 {$this.{Listen Dns Queries} = "No"}
            1 {$this.{Listen Dns Queries} = "Yes"}
        }

        $this.{vStore Id} = $lifReceived.vstoreId
        $this.{vStore Name} = $lifReceived.vstoreName
    }
}