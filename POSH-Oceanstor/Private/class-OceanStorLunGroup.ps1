class OceanStorLunGroup{
	#Define Properties
	[int]${LunGroup ID}
	[string]${LunGroup Name}
	[string]$Description
	[string]${Application Type}
	[string]${LunGroup Type}
	[int64]${LunGroup Capacity}
	[string]${Application Configuration Data}
	[int]${vStore ID}
	[string]${vStore Name}
	[boolean]${Is Mapped}

	OceanStorLunGroup ([array]$LunGroupReceived)
	{
		$this.{LunGroup ID} = $LunGroupReceived.ID
		$this.{LunGroup Name} = $LunGroupReceived.NAME
		$this.Description = $LunGroupReceived.DESCRIPTION
		$this.{Application Type} = $LunGroupReceived.APPTYPE

		switch($LunGroupReceived.APPTYPE)
		{
			0 {$this.{Application Type} = "Other"}
			1 {$this.{Application Type} = "Oracle"}
			2 {$this.{Application Type} = "Exchange"}
			3 {$this.{Application Type} = "SQL Server"}
			4 {$this.{Application Type} = "VMWare"}
			5 {$this.{Application Type} = "Hyper-V"}
		}

		switch($LunGroupReceived.GROUPTYPE)
		{
			0 {$this.{LunGroup Type} = "LUN group"}
		}

		$this.{LunGroup Capacity} = $LunGroupReceived.CAPCITY / 1GB
		$this.{Application Configuration Data} = $LunGroupReceived.CONFIGDATA
		$this.{vStore ID} = $LunGroupReceived.vstoreid
		$this.{vStore Name} = $LunGroupReceived.vstoreName

		if ($LunGroupReceived.ISADD2MAPPINGVIEW -eq "false")
		{
			$this.{Is Mapped} = $false
		} elseif ($LunGroupReceived.ISADD2MAPPINGVIEW -eq "true") {
			$this.{Is Mapped} = $true
		}
	}
}