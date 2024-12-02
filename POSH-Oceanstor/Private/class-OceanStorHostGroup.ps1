class OceanStorHostGroup{
	#Define Properties
	[int]${Id}
	[string]${Name}
	[string]$Description
	[string]${HostGroup Type}
	[int]${vStore ID}
	[string]${vStore Name}
	[boolean]${Is Mapped}
	[string]${Host Member Number} # for v6
	[string]${Mapped Luns Number} # for v6
	[string]${Total Capacity} # for v6
	[string]${Allocated Capacity} # For v6
	[string]${Protection Capacity} # For V6

	OceanStorHostGroup ([array]$HostGroupReceived)
	{
		$this.{HostGroup ID} = $HostGroupReceived.ID
		$this.{HostGroup Name} = $HostGroupReceived.NAME
		$this.Description = $HostGroupReceived.DESCRIPTION
		$this.{HostGroup Type} = $HostGroupReceived.TYPE

		switch($HostGroupReceived.TYPE)
		{
			0 {$this.{HostGroup Type} = "Host Group"}
		}

		$this.{vStore ID} = $HostGroupReceived.vstoreid
		$this.{vStore Name} = $HostGroupReceived.vstoreName

		if ($HostGroupReceived.ISADD2MAPPINGVIEW -eq "false")
		{
			$this.{Is Mapped} = $false
		} elseif ($HostGroupReceived.ISADD2MAPPINGVIEW -eq "true") {
			$this.{Is Mapped} = $true
		}

		$this.{Host Member Number} = $HostGroupReceived.hostNumbe #for v6
		$this.{Mapped Luns Number} = $HostGroupReceived.mappingLunNumber #for v6
		$this.{Total Capacity} = $HostGroupReceived.capacity / 1GB #for v6
		$this.{Allocated Capacity} = $HostGroupReceived.allocatedCapacity / 1GB #for v6
		$this.{Protection Capacity} = $HostGroupReceived.protectionCapacity / 1GB #for v6

	}
}