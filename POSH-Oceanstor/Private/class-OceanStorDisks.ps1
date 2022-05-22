class OceanStorDisks{
	#Define Variables
	[string]$id
	[string]$location
	[string]$partNumber
	[string]$runningStatus
	[string]${Enclosure ID}
	[string]${parent Type}
	[string]$storeEngineId
	[string]$logicType
	[string]$manufacter
	[string]$model
	[int64]$manufacterCapacity
	[string]$encryptDiskType
	[string]$firmwareVersion
	[string]$healthMark
	[string]$healthStatus
	[boolean]$cofferDisk
	[string]$keyExpirationTime
	[string]$lightStatus
	[string]$multipath
	[string]$poolId
	[string]$poolName
	[string]$poolTierId
	[string]$progress
	[string]$remainLife
	[string]$runtime
	[string]$sectors
	[string]$sectorSize
	[string]$serialNumber
	[string]$smartCachePoolId
	[string]$speedRPM
	[string]$temperature
	[string]$type
	[string]$barCode
	[string]$formartProgress
	[string]$formatRemainTime

	OceanStorDisks ([array]$disks)
	{
		$this.encryptDiskType = $disks.ENCRYPTDISKTYPE
		$this.firmwareVersion = $disks.FIRMWAREVER
		$this.healthMark = $disks.HEALTHMARK

		switch($disks.HEALTHSTATUS)
		{
			0 {$this.healthStatus = "Unknown"}
			1 {$this.healthStatus = "Normal"}
			2 {$this.healthStatus = "Faulty"}
			3 {$this.healthStatus = "about to fail"}
		}

		$this.id = $disks.ID

		if ($disks.ISCOFFERDISK -eq "FALSE")
		{
			$this.cofferDisk = $false
		} elseif ($disks.ISCOFFERDISK -eq "TRUE")
		{
			$this.cofferDisk = $true
		}

		#$this.item = $disks.ITEM TO be solve for now using alternative way to get partNumber
		$this.partNumber = $($disks.barcode.Substring(0,10)).Substring(2)
		$this.keyExpirationTime = $disks.KEYEXPIRATIONTIME

		switch($disks.LIGHTSTATUS)
		{
			0 {$this.lightStatus = "off"}
			1 {$this.lightStatus = "blinking"}
			2 {$this.lightStatus = "steady on"}
		}

		$this.location = $disks.LOCATION

		switch($disks.LOGICTYPE)
		{
			1 {$this.logicType = "free"}
			2 {$this.logicType = "member"}
			3 {$this.logicType = "hot_spare"}
			4 {$this.logicType = "cache"}
		}

		$this.manufacter = $disks.MANUFACTURER
		$this.model = $disks.MODEL
		$this.multipath = $disks.MULTIPATH
		$this.{Enclosure ID} = $disks.PARENTID

		switch($disks.PARENTTYPE)
		{
			1 {$this.{Parent Type} = "Enclosure"}
		}

		$this.poolId = $disks.POOLID
		$this.poolName = $disks.POOLNAME
		$this.poolTierId = $disks.POOLTIERID
		$this.progress = $disks.PROGRESS
		$this.remainLife = $disks.REMAINLIFE

		switch($disks.RUNNINGSTATUS)
		{
			0 {$this.runningStatus = "unknown"}
			1 {$this.runningStatus = "Normal"}
			14 {$this.runningStatus = "pre-copy"}
			16 {$this.runningStatus = "reconstruction"}
			27 {$this.runningStatus = "online"}
			16 {$this.runningStatus = "offline"}
		}

		$this.runtime = $disks.RUNTIME
		$this.sectors = $disks.SECTORS
		$this.sectorSize = $disks.SECTORSIZE
		$this.serialNumber = $disks.SERIALNUMBER
		$this.smartCachePoolId = $disks.SMARTCACHEPOOLID
		$this.speedRPM = $disks.SPEEDRPM
		$this.storeEngineId = $disks.STORAGEENGINEID
		$this.temperature = $disks.TEMPERATURE

		switch($disks.TYPE)
		{
			0 {$this.type = "FC"}
			1 {$this.type = "SAS"}
			2 {$this.type = "SATA"}
			3 {$this.type = "SSD"}
			4 {$this.type = "NL-SAS"}
			5 {$this.type = "SLC SSD"}
			6 {$this.type = "MLC SSD"}
			7 {$this.type = "FC SED"}
			8 {$this.type = "SAS SED"}
			9 {$this.type = "SATA SED"}
			10 {$this.type = "SSD SED"}
			11 {$this.type = "NL-SAS SED"}
			12 {$this.type = "SLC SSD SED"}
			13 {$this.type = "MLC SSD SED"}
		}

		$this.barCode = $disks.barcode
		$this.formartProgress = $disks.formatProgress
		$this.formatRemainTime = $disks.formatRemainTime
		$this.manufacterCapacity = $disks.manuCapacity / 1GB
	}
}