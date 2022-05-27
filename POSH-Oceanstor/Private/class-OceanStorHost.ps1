class OceanStorHost{
	#Define Properties
	[string]$id
	[string]$name
	[string]${Healh Status}
	[string]${Running Status}
	[string]$type
	[string]$description
	[string]$parentid
	[string]$parentname
	[string]$parenttype
	[string]$initiatornum
	[string]$ip
	[boolean]$isadd2hostgroup
	[string]$location
	[string]$model
	[string]$networkname
	[string]${Operation System}
	[int]${vStore ID}
	[string]${vStore Name}

	OceanStorHost ([array] $hostReceived)
	{
		$this.description = $hostReceived.DESCRIPTION

		switch($hostReceived.HEALTHSTATUS)
		{
			1 {$this.{Healh Status} = "Normal"}
			17 {$this.{Healh Status} = "No Redundant link"}
			18 {$this.{Healh Status} = "Offline"}
		}

		$this.id = $hostReceived.ID
		$this.initiatornum = $hostReceived.INITIATORNUM
		$this.ip = $hostReceived.IP

		switch($hostReceived.ISADD2HOSTGROUP)
		{
			true {$this.isadd2hostgroup = $true}
			false {$this.isadd2hostgroup = $false}
		}

		$this.location = $hostReceived.LOCATION
		$this.model = $hostReceived.MODEL
		$this.name = $hostReceived.NAME
		$this.networkname = $hostReceived.NETWORKNAME

		switch($hostReceived.OPERATIONSYSTEM)
		{
			0 {$this.{Operation System} = "Linux"}
			1 {$this.{Operation System} = "Windows"}
			2 {$this.{Operation System} = "Solaris"}
			3 {$this.{Operation System} = "HP-UX"}
			4 {$this.{Operation System} = "AIX"}
			5 {$this.{Operation System} = "XenServer"}
			6 {$this.{Operation System} = "Mac OS"}
			7 {$this.{Operation System} = "VMware ESX"}
			8 {$this.{Operation System} = "LINUX_VIS"}
			9 {$this.{Operation System} = "Windows Server 2012"}
			10 {$this.{Operation System} = "Oracle VM"}
			11 {$this.{Operation System} = "OpenVMS"}
			12 {$this.{Operation System} = "Oracle_VM_Server_for_x86"}
			13 {$this.{Operation System} = "Oracle_VM_Server_for_SPARC"}
		}

		$this.parentid = $hostReceived.PARENTID
		$this.parentname = $hostReceived.PARENTNAME

		switch($hostReceived.PARENTTYPE)
		{
			14 {$this.parenttype  = "Host Group"}
			245 {$this.parenttype  = "Mapping View"}
		}

		switch($hostReceived.RUNNINGSTATUS)
		{
			1 {$this.{Running Status}  = "normal"}
		}

		switch($hostReceived.TYPE)
		{
			21 {$this.type  = "Host"}
		}

        $this.{vStore ID} = $hostReceived.vstoreid
		$this.{vStore Name} = $hostReceived.vstoreName
	}
}