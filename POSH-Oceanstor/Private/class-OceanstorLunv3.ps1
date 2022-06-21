class OceanstorLunv3{
	#Define Lun ID (id)
	[Int]$id

	#Define Lun Name (name)
	[string]$name

	#Define Lun Type (ALLOCTYPE)
	[string]$type

	#Define wwn
	[string]$wwn

	#define Lun Health Status
	[string]$health

	#define Lun Running Status
	[string]$runningStatus

	#Define StoragePoolID
	[Int]$StoragePoolId

	#Define StoragePoolName (PARENTID)
	[string]$StoragePool

	#Define Description
	[string]$description

	#define SpaceAlocated (capacity)
	[Int64]$Size

	#define SpaceUsed (alloccapacity)
	[Int64]$SpaceUsed

	#define
	[string]$owningController

	#define
	[string]$runningController

	#Define Dedupe Variables
	[boolean]$dedupeEnabled
	[int64]$dedupeSavedCapacity
	[int64]$dedupeSavedRatio

	#Define Compression
	[boolean]$compressionEnabled
	[int64]$compressionSavedCapacity
	[int64]$compressionSavedRatio

	#Define SavedCpacity
	[int64]$totalsavedcapacity
	[int64]$totalsavedratio

	[int64]$SpaceBeforeSaving

	#Define vStore
	[int]${vStore ID}
	[string]${vStore Name}

	OceanstorLunv3 ([array]$LunReceived,[pscustomobject]$ObjStorage)
	{
		$lunID = $LunReceived.ID
		$this.id = $lunID

		$lunName = $LunReceived.NAME
		$this.name = $LunName

		$LunALLOCTYPE = $LunReceived.ALLOCTYPE
		switch ($LunALLOCTYPE)
		{
			0 {$this.type = "Thick"}
			1 {$this.type = "Thin"}
		}

		$LunWWN = $LunReceived.WWN
		$this.wwn = $LunWWN

		switch($LunReceived.HEALTHSTATUS)
		{
			1 {$this.health = "Normal"}
			2 {$this.health = "Faulty"}
		}

		switch($LunReceived.RUNNINGSTATUS)
		{
			27 {$this.runningStatus = "Online"}
			28 {$this.runningStatus = "Offline"}
			53 {$this.runningStatus = "Initializing"}
		}

		$this.StoragePoolId = $LunReceived.PARENTID
		$this.StoragePool = $LunReceived.PARENTNAME

		[int64]$LunSectorSize = $LunReceived.SECTORSIZE
		[int64]$LunCapacity = $LunReceived.CAPACITY
		[int64]$LunSize = $LunCapacity * $LunSectorSize / 1GB
		$this.Size = $LunSize

		[int64]$lunAllocCapacity = $LunReceived.ALLOCCAPACITY
		$LunSpaceUsed = $lunAllocCapacity * $LunSectorSize / 1GB
		$this.SpaceUsed = $LunSpaceUsed

		$this.owningController = $LunReceived.OWNINGCONTROLLER
		$this.runningController = $LunReceived.WORKINGCONTROLLER

		if ($LunReceived.ENABLEDEDUP -eq "FALSE")
		{
			$this.dedupeEnabled = $false
		} elseif ($LunReceived.ENABLEDEDUP -eq "TRUE")
		{
			$this.dedupeEnabled = $true
		}

		$this.dedupeSavedCapacity = $LunReceived.DEDUPSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.dedupeSavedRatio = $LunReceived.DEDUPSAVEDRATIO

		if ($LunReceived.ENABLECOMPRESSION -eq "FALSE")
		{
			$this.compressionEnabled = $false
		} elseif ($LunReceived.ENABLECOMPRESSION -eq "TRUE")
		{
			$this.compressionEnabled = $true
		}

		$this.compressionSavedCapacity = $LunReceived.COMPRESSIONSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.compressionSavedRatio = $LunReceived.COMPRESSIONSAVEDRATIO

		$this.totalsavedcapacity = $LunReceived.TOTALSAVEDCAPACITY * $LunSectorSize / 1GB
		$this.totalsavedratio = $LunReceived.TOTALSAVEDRATIO
		$this.SpaceBeforeSaving = $LunReceived.SAVEDAGOTOTALCAPACITY * $LunSectorSize / 1GB

        $this.{vStore ID} = $LunReceived.vstoreid
		$this.{vStore Name} = $LunReceived.vstoreName

	}
}