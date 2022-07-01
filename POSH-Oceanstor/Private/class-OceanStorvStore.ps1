class OceanStorvStore{
	#Define Properties
	[int]${ID}
	[string]${Name}
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