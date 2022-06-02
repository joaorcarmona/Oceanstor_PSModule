class OceanStorHost{
	#Define Properties
	[string]$id
	[string]$name
	[string]${Health Status}
	[string]${Running Status}
	[string]$type
	[string]$description
	[string]${HostGroup Name}
	[string]${HostGroup Id}
	[string]${MappingView Name}
	[string]${MappingView Id}
	[string]${Parent Type}
	[string]${Initiators Number}
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
			1 {$this.{Health Status} = "Normal"}
			17 {$this.{Health Status} = "No Redundant link"}
			18 {$this.{Health Status} = "Offline"}
		}

		$this.id = $hostReceived.ID
		$this.{Initiators Number} = $hostReceived.INITIATORNUM
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

		switch($hostReceived.PARENTTYPE)
		{
			14
			{
				$this.{Parent Type}  = "Host Group"
				$this.{HostGroup Name} = $hostReceived.PARENTNAME
				$this.{HostGroup Id} = $hostReceived.PARENTID
			}
			245
			{
				$this.{Parent Type}  = "Mapping View"
				$this.{MappingView Name} = $hostReceived.PARENTNAME
				$this.{MappingView Id} = $hostReceived.PARENTID
			}
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