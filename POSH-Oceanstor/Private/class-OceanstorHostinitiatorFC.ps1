class OceanstorHostinitiatorFC {
    #Define properties
    [string]${Id}
    [string]${Host Id}
    [string]${Host Name}
    [string]${Parent Type}
    [string]${Type}
    [string]${Health Status}
    [string]${Running Status}
    [string]${Failover Mode}
    [boolean]${Is Free}
    [string]${Multipath}
    [string]${Special Mode}
    [string]${Path}
    [string]${Operating System}
    [int]${vStore ID}
	[string]${vStore Name}

    OceanstorHostinitiatorFC ([array]$initiator)
    {
        $this.{Id} = $initiator.ID
        $this.{Host Id} = $initiator.PARENTID
        $this.{Host Name} = $initiator.PARENTNAME

        switch ($initiator.PARENTTYPE)
        {
            21 {$this.{Parent Type} = "Host"}
        }

        switch ($initiator.TYPE)
        {
            223 {$this.{Type} = "FC Initiator"}
        }

        switch ($initiator.HEALTHSTATUS)
        {
            1 {$this.{Health Status} = "Normal"}
        }

        switch ($initiator.RUNNINGSTATUS)
        {
            0 {$this.{Running Status} = "Unknown"}
            27 {$this.{Running Status} = "Online"}
            28 {$this.{Running Status} = "Offline"}
        }

        switch ($initiator.FAILOVERMODE)
        {
            1 {$this.{Failover Mode} = "early-version ALUA"}
            2 {$this.{Failover Mode} = "ALUA not used"}
            3 {$this.{Failover Mode} = "special ALUA"}
            255 {$this.{Failover Mode} = "unknown"}
        }

        switch ($initiator.ISFREE)
        {
            true {$this.{Is Free} = $true}
            false {$this.{Is Free} = $false}
        }

        switch ($initiator.MULTIPATHTYPE)
        {
            0 {$this.{Multipath} = "Default"}
            1 {$this.{Multipath} = "Third-party"}
        }

        switch ($initiator.SPECIALMODETYPE)
        {
            0 {$this.{Special Mode} = "mode 0"}
            1 {$this.{Special Mode} = "mode 1"}
            2 {$this.{Special Mode} = "mode 2"}
            3 {$this.{Special Mode} = "mode 3"}
            255 {$this.{Special Mode} = "unknown"}
        }

        switch ($initiator.PATHTYPE)
        {
            0 {$this.{Path} = "Preferred Path"}
            1 {$this.{Path} = "Non-preferred"}
            255 {$this.{Path} = "third-party"}
        }

        switch ($initiator.OPERATIONSYSTEM)
        {
            0 {$this.{Operating System} = "Linux"}
            1 {$this.{Operating System} = "Windows"}
            2 {$this.{Operating System} = "Solaris"}
            3 {$this.{Operating System} = "HP-UX"}
            4 {$this.{Operating System} = "AIX"}
            5 {$this.{Operating System} = "XenServer"}
            6 {$this.{Operating System} = "MAC OS"}
            7 {$this.{Operating System} = "VMware ESX"}
            8 {$this.{Operating System} = "LINUX_VIS"}
            9 {$this.{Operating System} = "Windows Server 2012"}
            10 {$this.{Operating System} = "Oracle VM"}
            11 {$this.{Operating System} = "OpenVMS"}
            12 {$this.{Operating System} = "Oracle_VM_Server_for_x86"}
            13 {$this.{Operating System} = "Oracle_VM_Server_for_SPARC"}
            255 {$this.{Operating System} = "Unknown"}
        }

        $this.{vStore ID} = $initiator.vstoreid
		$this.{vStore Name} = $initiator.vstoreName
    }

}