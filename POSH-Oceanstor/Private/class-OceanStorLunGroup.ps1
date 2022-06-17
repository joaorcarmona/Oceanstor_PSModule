class OceanStorLunGroup{
	#Define Properties
	[int]${LunGroup ID}
	[string]${LunGroup Name}
	[string]$Description
	[string]${Application Type} # for v3 only
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

		$this.{Luns Members number} = $LunGroupReceived.lunNumber # Only for v6
		$this.{Allocated Capacity} = $LunGroupReceived.allocatedCapacity # Only for v6
		$this.{Protection Capacity} = $LunGroupReceived.protectionCapacity # Only for v6
		$this.{HyperCDP Consistency Group Number} = $LunGroupReceived.cdpGroupNum # Only for v6
		$this.{Replication Group Number} = $LunGroupReceived.replicationGroupNum # Only for v6
		$this.{Snapshot Group Number} = $LunGroupReceived.snapshotGroupNum # Only for v6
		$this.{HyperMetro Group Number} = $LunGroupReceived.hyperMetroGroupNum # Only for v6
		$this.{Clone Group Number} = $LunGroupReceived.cloneGroupNum # Only for v6
		$this.{DR Start Trio Number} = $LunGroupReceived.drStarNum # Only for v6
	}
}