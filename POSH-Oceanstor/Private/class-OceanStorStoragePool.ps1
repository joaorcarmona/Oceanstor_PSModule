class OceanStorStoragePool{
	#TODO DEFINE Properties with friendly Name & complete information
	#Define Properties
	[string]$id
	[string]$name
	[string]$type
	[string]${Health Status}
	[string]${Running Status}
	[string]${Parent Id}
	[string]${Parent Name}
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

		switch($spoolReceived.dststatus)
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
			1 {$this.{Health Status} = "Normal"}
			2 {$this.{Health Status} = "Fault"}
			3 {$this.{Health Status} = "Degraded"}
		}

		switch($spoolReceived.IMMEDIATEMIGRATION)
		{
			false {$this.immediatemigration = "off"}
			true {$this.immediatemigration = "on"}
		}

		if ($spoolReceived.IMMEDIATEMIGRATIONDURATIONTIME)
		{
			$this.immediatemigrationdurationtime = $(New-TimeSpan -Seconds $spoolReceived.IMMEDIATEMIGRATIONDURATIONTIME).ToString()
		}

		switch($spoolReceived.ISSMARTTIERENABLE)
		{
			false {$this.issmarttierenable = "invalid"}
			true {$this.issmarttierenable = "valid"}
		}

		$this.lunconfigedcapacity = $spoolReceived.LUNCONFIGEDCAPACITY / $sectorSize / $unitUsed

		if($spoolReceived.MIGRATIONESTIMATEDTIME)
		{
			$this.migrationestimatedtime = $(New-TimeSpan -Seconds $spoolReceived.MIGRATIONESTIMATEDTIME).ToString()
		}

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
		$this.{Parent Id} = $spoolReceived.PARENTID
		$this.{Parent Name} = $spoolReceived.PARENTNAME

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
			14 {$this.{Running Status} = "pre-copy"}
			26 {$this.{Running Status} = "reconstruction"}
			27 {$this.{Running Status} = "online"}
			28 {$this.{Running Status} = "offline"}
			32 {$this.{Running Status} = "balancing"}
			53 {$this.{Running Status} = "initializing"}
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