#Class Module
class OceanStorSystem{
	#Define SN
	[string]$sn
	[string]$version
	[string]$WWN
	[string]$location
	[string]$description
	[string]${Health Status}
	[string]${Running Status}
	[int]$HotSpareNumbers

	OceanStorSystem ([array]$systemArray)
	{
		$SystemProperties = @{}

		foreach ($line in $systemArray)
		{

			$sysprop = $line.split("=")
			$key = $sysprop[0]
			$value = $sysprop[1]
			$SystemProperties.add($key.trim(), $value)
		}
		$this.sn = $SystemProperties["ID"]
		$sysProductVersion = $SystemProperties.PRODUCTVERSION
		$this.version = $sysProductVersion
		$this.WWN = $SystemProperties["wwn"]
		$this.location = $SystemProperties["LOCATION"]
		$sysDescription = $SystemProperties.DESCRIPTION
		$this.description = $sysDescription

		switch($SystemProperties.HEALTHSTATUS)
		{
			1 {$this.{Health Status} = "Normal"}
			2 {$this.{Health Status} = "Faulty"}
		}

		switch($SystemProperties.RUNNINGSTATUS)
		{
			1 {$this.{Running Status} = "Normal"}
			3 {$this.{Running Status} = "Not Running"}
			12 {$this.{Running Status} = "Powering on"}
			47 {$this.{Running Status} = "Powering off"}
			51 {$this.{Running Status} = "Upgrading"}
		}

		$this.HotSpareNumbers = $SystemProperties["HOTSPAREDISKSCAPACITY"]
	}
}

class OceanstorDeviceLun{
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

	OceanstorDeviceLun ([array]$LunReceived)
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

	}
}

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

#TODO Create MappingView Class
<# class OceanStorMappingView{

} #>


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

class OceanStorStoragePool{
	#TODO DEFINE Properties with friendly Name & complete information
	#Define Properties
	[string]$id
	[string]$name
	[string]$type
	[string]$healthstatus
	[string]$runningstatus
	[string]$parentid
	[string]$parentname
	[string]$description
	[string]$autodeactivesnapshotswitch
	[int64]$dataspace
	[string]$dstrunningstatus
	[string]$dststatus
	[string]$enablesmartcache
	[string]$enablessdbuffer
	[string]$extentsize
	[string]$immediatemigration
	[string]$immediatemigrationdurationtime
	[string]$issmarttierenable
	[int64]$lunconfigedcapacity
	[string]$migrationestimatedtime
	[string]$migrationmode
	[string]$migrationscheduleid
	[string]$monitorscheduleid
	[int64]$moveddowndata
	[int64]$movedowndata
	[int64]$movedupdata
	[int64]$moveupdata
	[string]$pausemigrationswitch
	[string]$repcapacitythreshold
	[int64]$replicationcapacity
	[int64]$reservedcapacity
	[int64]$tier0capacity
	[string]$tier0disktype
	[string]$tier0raiddisknum
	[string]$tier0raidlv
	[int64]$tier0stripedepth
	[int64]$tier1capacity
	[string]$tier1disktype
	[string]$tier1raiddisknum
	[string]$tier1raidlv
	[int64]$tier1stripedepth
	[int64]$tier2capacity
	[string]$tier2disktype
	[string]$tier2raiddisknum
	[string]$tier2raidlv
	[int64]$tier2stripedepth
	[int64]$totalfscapacity
	[string]$usagetype
	[int64]$userconsumedcapacity
	[string]$userconsumedcapacitypercentage
	[string]$userconsumedcapacitythreshold
	[int64]$userfreecapacity
	[int64]$usertotalcapacity
	[string]$compressratio
	[int64]$compressedcapacity
	[string]$dedupcompressratio
	[string]$dedupratio
	[int64]$dedupedcapacity
	[string]$reductioninvolvedcapacity

	OceanStorStoragePool ([array]$spoolReceived)
	{
		#Define Constants for Space Operations
		$sectorSize = 512
		$unitUsed = 1GB

		$this.id = $spoolReceived.ID
		$this.autodeactivesnapshotswitch = $spoolReceived.AUTODEACTIVESNAPSHOTSWITCH

		switch($spoolReceived.AUTODEACTIVESNAPSHOTSWITCH)
		{
			0 {$this.autodeactivesnapshotswitch = "on"}
			1 {$this.autodeactivesnapshotswitch = "off"}
		}

		$this.dataspace = $spoolReceived.DATASPACE / $sectorSize  / $unitUsed
		$this.description = $spoolReceived.DESCRIPTION

		switch($spoolReceived.DSTRUNNINGSTATUS)
		{
			1 {$this.dstrunningstatus = "ready"}
			2 {$this.dstrunningstatus = "migrated"}
			3 {$this.dstrunningstatus = "suspended"}
		}

		switch($spoolReceived.HEALTHSTATUS)
		{
			1 {$this.dststatus = "active"}
			2 {$this.dststatus = "inactive"}
		}

		switch($spoolReceived.ENABLESMARTCACHE)
		{
			false {$this.enablesmartcache = "disabled"}
			true {$this.enablesmartcache = "enabled"}
		}

		switch($spoolReceived.ENABLESSDBUFFER)
		{
			false {$this.enablessdbuffer = "disabled"}
			true {$this.enablessdbuffer = "enabled"}
		}

		switch($spoolReceived.ENABLESSDBUFFER)
		{
			false {$this.enablessdbuffer = "disabled"}
			true {$this.enablessdbuffer = "enabled"}
		}

		$this.extentsize = $spoolReceived.EXTENTSIZE / $sectorSize  / $unitUsed

		switch($spoolReceived.HEALTHSTATUS)
		{
			1 {$this.healthstatus = "Normal"}
			2 {$this.healthstatus = "Fault"}
			3 {$this.healthstatus = "Degraded"}
		}

		switch($spoolReceived.IMMEDIATEMIGRATION)
		{
			false {$this.immediatemigration = "off"}
			true {$this.immediatemigration = "on"}
		}

		$this.immediatemigrationdurationtime = $(New-TimeSpan -Seconds $spoolReceived.IMMEDIATEMIGRATIONDURATIONTIME).ToString()

		switch($spoolReceived.ISSMARTTIERENABLE)
		{
			false {$this.issmarttierenable = "invalid"}
			true {$this.issmarttierenable = "valid"}
		}

		$this.lunconfigedcapacity = $spoolReceived.LUNCONFIGEDCAPACITY / $sectorSize / $unitUsed
		$this.migrationestimatedtime = $(New-TimeSpan -Seconds $spoolReceived.MIGRATIONESTIMATEDTIME).ToString()

		switch($spoolReceived.MIGRATIONMODE)
		{
			1 {$this.migrationmode = "dynamic"}
			2 {$this.migrationmode = "manual"}
		}

		$this.migrationscheduleid = $spoolReceived.MIGRATIONSCHEDULEID
		$this.monitorscheduleid = $spoolReceived.MONITORSCHEDULEID
		$this.moveddowndata = $spoolReceived.MOVEDDOWNDATA / $sectorSize / $unitUsed
		$this.movedowndata = $spoolReceived.MOVEDOWNDATA  / $sectorSize / $unitUsed
		$this.movedupdata = $spoolReceived.MOVEDUPDATA / $sectorSize / $unitUsed
		$this.moveupdata = $spoolReceived.MOVEUPDATA / $sectorSize / $unitUsed
		$this.name = $spoolReceived.NAME
		$this.parentid = $spoolReceived.PARENTID
		$this.parentname = $spoolReceived.PARENTNAME

		switch($spoolReceived.PAUSEMIGRATIONSWITCH)
		{
			false {$this.pausemigrationswitch = "off"}
			true {$this.pausemigrationswitch = "on"}
		}

		$this.repcapacitythreshold = $spoolReceived.REPCAPACITYTHRESHOLD
		$this.replicationcapacity = $spoolReceived.REPLICATIONCAPACITY / $sectorSize / $unitUsed
		$this.reservedcapacity = $spoolReceived.RESERVEDCAPACITY / $sectorSize / $unitUsed

		switch($spoolReceived.RUNNINGSTATUS)
		{
			14 {$this.runningstatus = "pre-copy"}
			26 {$this.runningstatus = "reconstruction"}
			27 {$this.runningstatus = "online"}
			28 {$this.runningstatus = "offline"}
			32 {$this.runningstatus = "balancing"}
			53 {$this.runningstatus = "initializing"}
		}

		$this.tier0capacity = $spoolReceived.TIER0CAPACITY / $sectorSize / $unitUsed

		switch($spoolReceived.TIER0DISKTYPE)
		{
			0 {$this.tier0disktype = "Not Available/Not Used"}
			3 {$this.tier0disktype = "SSD"}
			10 {$this.tier0disktype = "SSD SED"}
		}

		$this.tier0raiddisknum = $spoolReceived.TIER0RAIDDISKNUM

		switch($spoolReceived.TIER0RAIDLV)
		{
			0 {$this.tier0raidlv = "Not Available/Not Used"}
			1 {$this.tier0raidlv = "RAID 10"}
			2 {$this.tier0raidlv = "RAID 5"}
			3 {$this.tier0raidlv = "RAID 0"}
			4 {$this.tier0raidlv = "RAID 1"}
			5 {$this.tier0raidlv = "RAID 6"}
			6 {$this.tier0raidlv = "RAID 50"}
			7 {$this.tier0raidlv = "RAID 3"}
		}

		$this.tier0stripedepth = $spoolReceived.TIER0STRIPEDEPTH / $sectorSize / $unitUsed
		$this.tier1capacity = $spoolReceived.TIER1CAPACITY / $sectorSize / $unitUsed

		switch($spoolReceived.TIER1DISKTYPE)
		{
			0 {$this.tier1disktype = "Not Available/Not Used"}
			3 {$this.tier1disktype = "SAS"}
			10 {$this.tier1disktype = "SAS SED"}
		}

		$this.tier1raiddisknum = $spoolReceived.TIER1RAIDDISKNUM

		switch($spoolReceived.TIER1RAIDLV)
		{
			0 {$this.tier1raidlv = "Not Available/Not Used"}
			1 {$this.tier1raidlv = "RAID 10"}
			2 {$this.tier1raidlv = "RAID 5"}
			3 {$this.tier1raidlv = "RAID 0"}
			4 {$this.tier1raidlv = "RAID 1"}
			5 {$this.tier1raidlv = "RAID 6"}
			6 {$this.tier1raidlv = "RAID 50"}
			7 {$this.tier1raidlv = "RAID 3"}
		}

		$this.tier1stripedepth = $spoolReceived.TIER1STRIPEDEPTH / $sectorSize / $unitUsed
		$this.tier2capacity = $spoolReceived.TIER2CAPACITY / $sectorSize / $unitUsed

		switch($spoolReceived.TIER2DISKTYPE)
		{
			0 {$this.tier2disktype = "Not Available/Not Used"}
			2 {$this.tier2disktype = "SATA"}
			4 {$this.tier2disktype = "NL-SAS"}
			11 {$this.tier2disktype = "NL-SAS SED"}
		}

		$this.tier2raiddisknum = $spoolReceived.TIER2RAIDDISKNUM

		switch($spoolReceived.TIER2RAIDLV)
		{
			0 {$this.tier2raidlv = "Not Available/Not Used"}
			1 {$this.tier2raidlv = "RAID 10"}
			2 {$this.tier2raidlv = "RAID 5"}
			3 {$this.tier2raidlv = "RAID 0"}
			4 {$this.tier2raidlv = "RAID 1"}
			5 {$this.tier2raidlv = "RAID 6"}
			6 {$this.tier2raidlv = "RAID 50"}
			7 {$this.tier2raidlv = "RAID 3"}
		}


		$this.tier2stripedepth = $spoolReceived.TIER2STRIPEDEPTH / $sectorSize / $unitUsed
		$this.totalfscapacity = $spoolReceived.TOTALFSCAPACITY / $sectorSize / $unitUsed
		$this.type = $spoolReceived.TYPE

		switch($spoolReceived.USAGETYPE)
		{
			1 {$this.usagetype = "LUN"}
			2 {$this.usagetype = "File System"}
		}

		$this.userconsumedcapacity = $spoolReceived.USERCONSUMEDCAPACITY / $sectorSize / $unitUsed
		$this.userconsumedcapacitypercentage = $spoolReceived.USERCONSUMEDCAPACITYPERCENTAGE
		$this.userconsumedcapacitythreshold = $spoolReceived.USERCONSUMEDCAPACITYTHRESHOLD
		$this.userfreecapacity = $spoolReceived.USERFREECAPACITY / $sectorSize / $unitUsed
		$this.usertotalcapacity = $spoolReceived.USERTOTALCAPACITY / $sectorSize / $unitUsed
		$this.compressratio = $spoolReceived.compressRatio
		$this.compressedcapacity = $spoolReceived.compressedCapacity / $sectorSize / $unitUsed
		$this.dedupcompressratio = $spoolReceived.dedupCompressRatio
		$this.dedupratio = $spoolReceived.dedupRatio
		$this.dedupedcapacity = $spoolReceived.dedupedCapacity / $sectorSize / $unitUsed
		$this.reductioninvolvedcapacity = $spoolReceived.reductionInvolvedCapacity / $sectorSize / $unitUsed
	}
}

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

class OceanStorHost{
	#Define Properties
	[string]$id
	[string]$name
	[string]${Healh Status}
	[string]${Running Status}
	[string]$type
	[string]$description
	[string]$parentid
	[string]$parentname
	[string]$parenttype
	[string]$initiatornum
	[string]$ip
	[boolean]$isadd2hostgroup
	[string]$location
	[string]$model
	[string]$networkname
	[string]${Operation System}

	OceanStorHost ([array] $hostReceived)
	{
		$this.description = $hostReceived.DESCRIPTION

		switch($hostReceived.HEALTHSTATUS)
		{
			1 {$this.{Healh Status} = "Normal"}
			17 {$this.{Healh Status} = "No Redundant link"}
			18 {$this.{Healh Status} = "Offline"}
		}

		$this.id = $hostReceived.ID
		$this.initiatornum = $hostReceived.INITIATORNUM
		$this.ip = $hostReceived.IP

		switch($hostReceived.ISADD2HOSTGROUP)
		{
			true {$this.isadd2hostgroup = $true}
			false {$this.isadd2hostgroup = $false}
		}

		$this.location = $hostReceived.LOCATION
		$this.model = $hostReceived.MODEL
		$this.name = $hostReceived.NAME
		$this.networkname = $hostReceived.NETWORKNAME

		switch($hostReceived.OPERATIONSYSTEM)
		{
			0 {$this.{Operation System} = "Linux"}
			1 {$this.{Operation System} = "Windows"}
			2 {$this.{Operation System} = "Solaris"}
			3 {$this.{Operation System} = "HP-UX"}
			4 {$this.{Operation System} = "AIX"}
			5 {$this.{Operation System} = "XenServer"}
			6 {$this.{Operation System} = "Mac OS"}
			7 {$this.{Operation System} = "VMware ESX"}
			8 {$this.{Operation System} = "LINUX_VIS"}
			9 {$this.{Operation System} = "Windows Server 2012"}
			10 {$this.{Operation System} = "Oracle VM"}
			11 {$this.{Operation System} = "OpenVMS"}
			12 {$this.{Operation System} = "Oracle_VM_Server_for_x86"}
			13 {$this.{Operation System} = "Oracle_VM_Server_for_SPARC"}
		}

		$this.parentid = $hostReceived.PARENTID
		$this.parentname = $hostReceived.PARENTNAME

		switch($hostReceived.PARENTTYPE)
		{
			14 {$this.parenttype  = "Host Group"}
			245 {$this.parenttype  = "Mapping View"}
		}

		switch($hostReceived.RUNNINGSTATUS)
		{
			1 {$this.{Running Status}  = "normal"}
		}

		switch($hostReceived.TYPE)
		{
			21 {$this.type  = "Host"}
		}
	}

}

class OceanstorSession{
    #Define Hostname Property OceanstorDeviceManager
	hidden [string]$Hostname

	#Define Host Credentials Property
	hidden [System.Management.Automation.PSCredential]$Credentials

	#Define DeviceID Property
	hidden [string]$DeviceId

	#Define WebSession Property
	hidden [Microsoft.PowerShell.Commands.WebRequestSession]$WebSession

	#Define Headers Array Property
	hidden [System.Collections.IDictionary]$Headers

	#Define iBaseToken Property
	hidden [string]$iBaseToken

	#Define Software Version
	hidden [string]$Version

    # Constructor
    OceanstorSession ([PSCustomObject] $logonSession, [System.Collections.IDictionary]$SessionHeader, [Microsoft.PowerShell.Commands.WebRequestSession]$webSession, [string] $hostname, [System.Management.Automation.PSCredential]$credentials)
    {
        $this.DeviceId = $logonsession.data.deviceid
        $this.WebSession = $WebSession
        $this.Headers = $SessionHeader
        $this.iBaseToken = $logonsession.data.iBaseToken
        $this.Credentials = $credentials
        $this.Hostname = $hostname

		$getDeviceManager = get-DMSystem -WebSession $this

		$this.Version = $getDeviceManager.version
    }
}