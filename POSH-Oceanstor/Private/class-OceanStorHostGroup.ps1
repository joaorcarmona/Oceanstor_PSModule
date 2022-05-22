class OceanStorHostGroup{
	#Define Properties
	[int]${HostGroup ID}
	[string]${HostGroup Name}
	[string]$Description
	[string]${HostGroup Type}
	[int]${vStore ID}
	[string]${vStore Name}
	[boolean]${Is Mapped}

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
	}
}