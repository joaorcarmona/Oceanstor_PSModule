class OceanStorDisks{
    [string]${Vendor Name}
	#Define Variables
	[string]$id
	[string]$location
	[string]${Part Number}
	[string]${Board Type}
    [string]${Description}
	[string]${Running Status}
	[string]${Enclosure ID}
	[string]${parent Type}
	[string]${Storage Engine Id}
	[string]${Disk Usage}
	[string]$manufacter
	[string]$Manufactured
	[string]$model
	[int64]${Manufacter Capacity (GB)}
	[string]$encryptDiskType
	[string]${Firmware Version}
	[string]$healthMark
	[string]${Health Status}
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
	[string]${Disk Type}
	[string]${Disk Format}
	[string]${Bar Code}
	[string]$formartProgress
	[string]$formatRemainTime

	OceanStorDisks ([array]$disks)
	{
		$this.encryptDiskType = $disks.ENCRYPTDISKTYPE
		$this.{Firmware Version} = $disks.FIRMWAREVER
		$this.healthMark = $disks.HEALTHMARK

		switch($disks.HEALTHSTATUS)
		{
			0 {$this.{Health Status} = "Unknown"}
			1 {$this.{Health Status} = "Normal"}
			2 {$this.{Health Status} = "Faulty"}
			3 {$this.{Health Status} = "about to fail"}
			17 {$this.{Health Status} = "single link"}
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
		$this.{Part Number} = $($disks.barcode.Substring(0,10)).Substring(2)
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
			1 {$this.{Disk Usage} = "free"}
			2 {$this.{Disk Usage} = "member"}
			3 {$this.{Disk Usage} = "hot_spare"}
			4 {$this.{Disk Usage} = "cache"}
		}

		$this.manufacter = $disks.MANUFACTURER
		$this.model = $disks.MODEL
		$this.multipath = $disks.MULTIPATH
		$this.{Enclosure ID} = $disks.PARENTID

		switch($disks.PARENTTYPE)
		{
			206 {$this.{Parent Type} = "Enclosure"}
		}

		$this.poolId = $disks.POOLID
		$this.poolName = $disks.POOLNAME
		$this.poolTierId = $disks.POOLTIERID
		$this.progress = $disks.PROGRESS
		$this.remainLife = $disks.REMAINLIFE

		switch($disks.RUNNINGSTATUS)
		{
			0 {$this.{Running Status} = "unknown"}
			1 {$this.{Running Status} = "Normal"}
			14 {$this.{Running Status} = "pre-copy"}
			16 {$this.{Running Status} = "reconstruction"}
			27 {$this.{Running Status} = "online"}
			16 {$this.{Running Status} = "offline"}
			114 {$this.{Running Status} = "erasing"}
			115 {$this.{Running Status} = "verifying"}
		}

		$this.runtime = $disks.RUNTIME
		$this.sectors = $disks.SECTORS
		$this.sectorSize = $disks.SECTORSIZE
		$this.serialNumber = $disks.SERIALNUMBER
		$this.smartCachePoolId = $disks.SMARTCACHEPOOLID
		$this.speedRPM = $disks.SPEEDRPM
		$this.{Storage Engine Id} = $disks.STORAGEENGINEID
		$this.temperature = $disks.TEMPERATURE

		switch($disks.TYPE)
		{
			0 {$this.{Disk Type} = "FC"}
			1 {$this.{Disk Type} = "SAS"}
			2 {$this.{Disk Type} = "SATA"}
			3 {$this.{Disk Type} = "SSD"}
			4 {$this.{Disk Type} = "NL-SAS"}
			5 {$this.{Disk Type} = "SLC SSD"}
			6 {$this.{Disk Type} = "MLC SSD"}
			7 {$this.{Disk Type} = "FC SED"}
			8 {$this.{Disk Type} = "SAS SED"}
			9 {$this.{Disk Type} = "SATA SED"}
			10 {$this.{Disk Type} = "SSD SED"}
			11 {$this.{Disk Type} = "NL-SAS SED"}
			12 {$this.{Disk Type} = "SLC SSD SED"}
			13 {$this.{Disk Type} = "MLC SSD SED"}
			14 {$this.{Disk Type} = "NVMe SSD"}
			16 {$this.{Disk Type} = "NVMe SSD SED"}
			17 {$this.{Disk Type} = "SCM"}
			18 {$this.{Disk Type} = "SCM SED"}
		}

		$this.{Bar Code} = $disks.barcode
		$this.formartProgress = $disks.formatProgress
		$this.formatRemainTime = $disks.formatRemainTime
		$this.{Manufacter Capacity (GB)} = $disks.manuCapacity / 1GB

		switch ($disks.DISKFORM)
		{
			0 {$this.{Disk Format} = "unknown"}
			1 {$this.{Disk Format} = "5.25-inch"}
			2 {$this.{Disk Format} = "3.5-inch"}
			3 {$this.{Disk Format} = "2.5-inch"}
			8 {$this.{Disk Format} = "1.8-inch"}
		}

		$labels =  get-DMparsedElabel -eLabelString $disks.ELABEL
        $this.{Board Type} = $labels.BoardType
        $this.{Bar Code} = $labels.BarCode
        $this.{Part Number} = $labels.Item
        $this.{Description} = $labels.Description
        $this.Manufactured = $labels.Manufactured
        $this.{Vendor Name} = $labels.VendorName
	}
}