class OceanStorvStore{
	hidden [pscustomobject]${Session}
	hidden [pscustomobject]${WebSession}
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

	OceanStorvStore ([array]$vStoresReceived, [pscustomobject]$WebSession)
	{
		$this.Session = $WebSession
		$this.WebSession = $WebSession
		$this.{ID} = $vStoresReceived.ID
		$this.{Name} = $vStoresReceived.NAME

		switch($vStoresReceived.RUNNINGSTATUS)
		{
			1 {$this.{Running Status} = "Online"}
			53 {$this.{Running Status}= "Initializing"}
		}

		$this.Description = $vStoresReceived.DESCRIPTION
		# Field names carry the Dorado 6.1.6 spelling "Quota" (the batch-vStore
		# interface exposes nasCapacityQuota/nasFreeCapacityQuota in sectors). The
		# SAN and *TotalCapacity fields are retained for V3-array compatibility.
		$this.{SAN Capacity Quota} = $vStoresReceived.sanCapacityQuota * 512 / 1GB

		if($vStoresReceived.sanFreeCapacityQuota -eq "-1" )
		{
			$this.{SAN Free Capacity Quota} = -1
		} else {
			$this.{SAN Free Capacity Quota} = $vStoresReceived.sanFreeCapacityQuota * 512 / 1GB
		}

		$this.{SAN Total Capacity} = $vStoresReceived.sanTotalCapacity * 512 / 1GB
		$this.{NAS Capacity Quota} = $vStoresReceived.nasCapacityQuota * 512 / 1GB

		if($vStoresReceived.nasFreeCapacityQuota -eq "-1" )
		{
			$this.{NAS Free Capacity Quota} = -1
		} else {
			$this.{NAS Free Capacity Quota} = $vStoresReceived.nasFreeCapacityQuota * 512 / 1GB
		}

		$this.{NAS Total Capacity} = $vStoresReceived.nasTotalCapacity * 512 / 1GB
	}
}


