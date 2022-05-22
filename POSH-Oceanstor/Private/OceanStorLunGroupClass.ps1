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

class OceanStorvStore{
	#Define Properties
	[int]${vStore ID}
	[string]${vStore Name}
	[string]${Running Status}
	[string]$Description
	[int64]${SAN Capacity Quota}
	[int64]${SAN Free Capacity Quota}
	[int64]${SAN Total Capacity}
	[int64]${NAS Capacity Quota}
	[int64]${NAS Free Capacity Quota}
	[int64]${NAS Total Capacity}

	OceanStorvStore ([array]$vStoresReceived)
	{
		$this.{vStore ID} = $vStoresReceived.ID
		$this.{vStore Name} = $vStoresReceived.NAME

		switch($vStoresReceived.RUNNINGSTATUS)
		{
			1 {$this.{Running Status} = "Online"}
			53 {$this.{Running Status}= "Initializing"}
		}

		$this.Description = $vStoresReceived.DESCRIPTION
		$this.{SAN Capacity Quota} = $vStoresReceived.sanCapacityQuata * 512 / 1GB

		if($vStoresReceived.sanFreeCapacityQuata -eq "-1" )
		{
			$this.{SAN Free Capacity Quota} = -1
		} else {
			$this.{SAN Free Capacity Quota} = $vStoresReceived.sanFreeCapacityQuata * 512 / 1GB
		}

		$this.{SAN Total Capacity} = $vStoresReceived.sanTotalCapacity * 512 / 1GB
		$this.{NAS Capacity Quota} = $vStoresReceived.nasCapacityQuata * 512 / 1GB

		if($vStoresReceived.nasFreeCapacityQuata -eq "-1" )
		{
			$this.{NAS Free Capacity Quota} = -1
		} else {
			$this.{NAS Free Capacity Quota} = $vStoresReceived.nasFreeCapacityQuata * 512 / 1GB
		}

		$this.{NAS Total Capacity} = $vStoresReceived.nasTotalCapacity * 512 / 1GB
	}
}