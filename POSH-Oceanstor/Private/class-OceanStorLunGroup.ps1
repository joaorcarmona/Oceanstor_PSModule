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
	[string]${Luns Members number} # for v6
	[string]${Allocated Capacity} # for v6
	[string]${Protection Capacity} # for v6
	[string]${HyperCDP Consistency Group Number} # for v6
	[string]${Replication Group Number} # for v6
	[string]${Snapshot Group Number} # for v6
	[string]${HyperMetro Group Number} # for v6
	[string]${Clone Group Number} # for v6
	[string]${DR Start Trio Number} # for v6

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

		$this.{Luns Members number} = $LunGroupReceived.lunNumber
		$this.{Allocated Capacity} = $LunGroupReceived.allocatedCapacity
		$this.{Protection Capacity} = $LunGroupReceived.protectionCapacity
		$this.{HyperCDP Consistency Group Number} = $LunGroupReceived.cdpGroupNum
		$this.{Replication Group Number} = $LunGroupReceived.replicationGroupNum
		$this.{Snapshot Group Number} = $LunGroupReceived.snapshotGroupNum
		$this.{HyperMetro Group Number} = $LunGroupReceived.hyperMetroGroupNum
		$this.{Clone Group Number} = $LunGroupReceived.cloneGroupNum
		$this.{DR Start Trio Number} = $LunGroupReceived.drStarNum
	}
}