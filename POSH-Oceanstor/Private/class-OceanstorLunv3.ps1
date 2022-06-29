class OceanstorLunv3{
	[string]${Object Type}
	[string]${Lun Id}
	[string]${Lun Name}
	[string]${Storage Pool Id}
	[string]${Storage Pool Name}
	[string]${Lun SubType}
	[string]${Health Status}
	[string]${Running Status}
	[string]${Description}
	[string]${Allocation Type}
	[int64]${Lun Size}
	[int64]${Lun Used Capacity}
	[int64]${Sector Size}
	[string]${is Mapped}
	[string]${WWN}
	[string]${Default Write Policy}
	[string]${Running Write Policy}
	[string]${Prefetch Policy}
	[string]${Prefetch Value}
	[string]${Owning Controller}
	[string]${Working Controller}
	[string]${Thin Capacity Usage}
	[string]${Owner Controller List}
	[string]${Belong Lun Group}
	[int64]${Replication Capacity}
	[string]${Remote Lun Id}
	[string]${Remote Lun WWN}
	[string]${Usage Type}
	[string]${iSCSI Thin Lun Threshold}
	[string]${iSCSI Thin Lun Threshold Enabled}
	[string]${External DIF Support}
	[string]${Value Added Service Status}
	[string]${VASA DRS Enabled}
	[string]${VASA Capabilities}
	[string]${VASA Thin Lun Severity}
	[string]${Mirror Type}
	[string]${Lun Masq Status}
	[string]${Takeover Lun WWN}
	[string]${Retention Time}
	[string]${Retention Set Time}
	[string]${Retention Status}
	[string]${Retention Term}
	[string]${Total Space Original}
	[string]${SmartCache Partition Id}
	[string]${SmartCache Hit Rate}
	[int64]${SmartCache Size}
	[string]${SmartCache State}
	[string]${IO Class Id}
	[string]${IO Priority}
	[string]${Cache Partition Id}
	[string]${SmartTier Enabled}
	[string]${TierData Initial Policy}
	[string]${TierData Distributing}
	[string]${TierData Migration Policy}
	[int64]${Tier Data Move Tier 0}
	[int64]${Tier Data Move Tier 1}
	[int64]${Tier Data Move Tier 2}
	[string]${Mirror Policy}
	[string]${Check Zero Page Enabled}
	[int64]${Metadata Capacity}
	[string]${DataDestruction Progress}
	[string]${Read Cache Policy}
	[string]${Write Cache Policy}
	[string]${Deduplication Enabled}
	[string]${Deduplication Check Enabled}
	[string]${Compression Enabled}
	[string]${SmartDedupe Enabled}
	[string]${Compression Algorithm}
	[string]${Deduplication Saved Ratio}
	[string]${Compression Saved Ratio}
	[string]${Total Saved Ratio}
	[int64]${Dedupe Saved Capacity}
	[int64]${Compression Saved Capacity}
	[int64]${Total Saved Capacity}
	[int64]${Total Consumer Space}
	[string]${vStore Id}
	[string]${vStore Name}

	OceanstorLunv3 ([array]$LunReceived,[pscustomobject]$ObjStorage)
	{
		switch ($lunReceived.TYPE)
		{
			11 {$this.{Object Type} = "LUN"}
		}

		$this.{Lun Id} = $LunReceived.ID
		$this.{Lun Name} = $LunReceived.NAME
		$this.{Storage Pool Id} = $lunReceived.PARENTID
		$this.{Storage Pool Name} = $lunReceived.PARENTNAME

		switch ($lunReceived.SUBTYPE)
		{
			1 {$this.{Lun SubType} = "VVol"}
			2 {$this.{Lun SubType} = "PE Lun"}
		}

		switch($LunReceived.HEALTHSTATUS)
		{
			1 {$this.{Health Status} = "Normal"}
			2 {$this.{Health Status} = "Faulty"}
			15 {$this.{Health Status} = "Write Protected"}
		}

		switch($LunReceived.RUNNINGSTATUS)
		{
			27 {$this.{Running Status} = "Online"}
			28 {$this.{Running Status} = "Offline"}
			53 {$this.{Running Status} = "Initializing"}
			106 {$this.{Running Status} = "Deleting"}
		}

		$this.{Description} = $lunReceived.DESCRIPTION

		switch ($LunReceived.ALLOCTYPE)
		{
			0 {$this.{Allocation Type} = "Thick"}
			1 {$this.{Allocation Type} = "Thin"}
		}
		[int64]$lSectorSize = $lunReceived.SECTORSIZE
		$this.{Sector Size} = $lSectorSize

		[int64]$lcapacity = $lunReceived.CAPACITY
		$this.{Lun Size} =  $lcapacity * $lSectorSize / 1GB

		[int64]$lAllocatedCap = $lunReceived.ALLOCCAPACITY
		$this.{Lun Used Capacity} = $lAllocatedCap * $lSectorSize / 1GB

		switch ($LunReceived.EXPOSEDTOINITIATOR)
		{
			false {$this.{is Mapped} = "not mapped"}
			true {$this.{is Mapped} = "mapped"}
		}

		$this.{WWN} = $lunReceived.WWN

		switch ($lunReceived.WRITEPOLICY)
		{
			1 {$this.{Default Write Policy} = "write back"}
			2 {$this.{Default Write Policy} = "write through"}
		}

		switch ($lunReceived.RUNNINGWRITEPOLICY)
		{
			1 {$this.{Running Write Policy} = "write back"}
			2 {$this.{Running Write Policy} = "write through"}
		}

		switch ($lunReceived.PREFETCHPOLICY)
		{
			0 {$this.{Prefetch Policy} = "no prefetech"}
			1 {$this.{Prefetch Policy} = "constant prefetech"}
			2 {$this.{Prefetch Policy} = "variable prefetech"}
			3 {$this.{Prefetch Policy} = "intelligent prefetech"}
		}

		$this.{Prefetch Value} = $lunReceived.PREFETCHVALUE
		$this.{Owning Controller} = $lunReceived.OWNINGCONTROLLER
		$this.{Working Controller} = $lunReceived.WORKINGCONTROLLER
		$this.{Thin Capacity Usage} = $lunReceived.THINCAPACITYUSAGE
		$this.{Owner Controller List} = $lunReceived.OWNERCONTROLLERLIST
		$this.{Belong Lun Group} = $lunReceived.ISADD2LUNGROUP

		[int64]$lReplicCap = $lunReceived.REPLICATION_CAPACITY
		$this.{Replication Capacity} = $lReplicCap * $lSectorSize / 1GB

		switch ($lunReceived.ISADD2LUNGROUP)
		{
			false {$this.{Belong Lun Group} = "no"}
			true {$this.{Belong Lun Group} = "yes"}
		}

		$this.{Remote Lun Id} = $lunReceived.REMOTELUNID

		switch ($lunReceived.USAGETYPE)
		{
			0 {$this.{Usage Type} = "traditional LUN"}
			1 {$this.{Usage Type} = "eDevLun"}
			2 {$this.{Usage Type} = "VVol LUN"}
			3 {$this.{Usage Type} = "PE LUN"}
		}
		$this.{Remote Lun WWN} = $lunReceived.remoteLunWwn
		$this.{iSCSI Thin Lun Threshold} = $lunReceived.ISCSITHINLUNTHRESHOLD

		switch ($lunReceived.ENABLEISCSITHINLUNTHRESHOLD)
		{
			false {$this.{iSCSI Thin Lun Threshold Enabled} = "off"}
			true {$this.{iSCSI Thin Lun Threshold Enabled} = "on"}
		}

		switch ($lunReceived.EXTENDIFSWITCH)
		{
			false {$this.{External DIF Support} = "not supported"}
			true {$this.{External DIF Support} = "supported"}
		}

		$this.{Value Added Service Status} = $lunReceived.HASRSSOBJECT

		switch ($lunReceived.DRS_ENABLE)
		{
			false {$this.{VASA DRS Enabled} = "not supported"}
			true {$this.{VASA DRS Enabled} = "supported"}
		}

		switch ($lunReceived.CAPABILITY)
		{
			0 {$this.{VASA Capabilities} = "No Protected"}
			1 {$this.{VASA Capabilities} = "Capacity"}
			2 {$this.{VASA Capabilities} = "Performance"}
			3 {$this.{VASA Capabilities} = "Extreme Performance"}
			4 {$this.{VASA Capabilities} = "Multi-Tiers"}
		}

		switch ($lunReceived.CAPACITYALARMLEVEL)
		{
			2 {$this.{VASA Thin Lun Severity} = "normal"}
			3 {$this.{VASA Thin Lun Severity} = "warning"}
			2 {$this.{VASA Thin Lun Severity} = "critical"}
		}

		switch ($lunReceived.MIRRORTYPE)
		{
			0 {$this.{Mirror Type} = "common LUN"}
			1 {$this.{Mirror Type} = "mirror LUN"}
			2 {$this.{Mirror Type} = "mirror copy LUN"}
		}

		switch ($lunReceived.DISGUISESTATUS)
		{
			0 {$this.{Lun Masq Status} = "no masquerading"}
			1 {$this.{Lun Masq Status} = "basic masquerading"}
			2 {$this.{Lun Masq Status} = "extended masquerading"}
			3 {$this.{Lun Masq Status} = "inherited masquerading"}
			4 {$this.{Lun Masq Status} = "3rd-party masquerading"}
		}

		$this.{Takeover Lun WWN} = $lunReceived.takeOverLunWwn
		$this.{Retention Time} = $lunReceived.REMAINRETENTIONTERM
		$this.{Retention Set Time} = $lunReceived.RETENTIONSETTIME

		switch ($lunReceived.RETENTIONSTATE)
		{
			1 {$this.{Retention Status} = "read only"}
			2 {$this.{Retention Status} = "read write"}
		}

		$this.{Retention Term} = $lunReceived.RETENTIONTERM
		$this.{Total Space Original} = $lunReceived.SAVEDAGOTOTALCAPACITY
		$this.{SmartCache Partition Id} = $lunReceived.SMARTCACHEPARTITIONID
		$this.{SmartCache Hit Rate} = $lunReceived.SC_HITRAGE
		$this.{SmartCache Size} = $lunReceived.SC_CACHEDSIZE
		$this.{SmartCache State} = $lunReceived.SMARTCACHESTATE
		$this.{IO Class Id} = $lunReceived.IOCLASSID

		switch ($lunReceived.IOPRIORITY)
		{
			1 {$this.{IO Priority} = "low"}
			2 {$this.{IO Priority} = "medium"}
			3 {$this.{IO Priority} = "lhigh"}
		}

		$this.{Cache Partition Id} = $lunReceived.CACHEPARTITIONID

		$this.{TierData Distributing} = $lunReceived.DATADISTRIBUTING

		switch ($lunReceived.DATATRANSFERPOLICY)
		{
			0 {$this.{TierData Migration Policy} = "no migration"}
			1 {$this.{TierData Migration Policy} = "automatic migration"}
			2 {$this.{TierData Migration Policy} = "migration to higher tier"}
			3 {$this.{TierData Migration Policy} = "migration to lower lier"}
		}

		switch ($lunReceived.INITIALDISTRIBUTEPOLICY)
		{
			0 {$this.{TierData Initial Policy} = "automatic"}
			1 {$this.{TierData Initial Policy} = "highest performance"}
			2 {$this.{TierData Initial Policy} = "performance"}
			3 {$this.{TierData Initial Policy} = "capacity"}
		}
		$this.{Tier Data Move Tier 0} = $lunReceived.MOVETOTIER0DATA
		$this.{Tier Data Move Tier 1} = $lunReceived.MOVETOTIER1DATA
		$this.{Tier Data Move Tier 2} = $lunReceived.MOVETOTIER2DATA

		switch ($lunReceived.MIRRORPOLICY)
		{
			0 {$this.{Mirror Policy} = "no mirroring"}
			1 {$this.{Mirror Policy} = "mirroring"}
		}

		switch ($lunReceived.ISCHECKZEROPAGE)
		{
			false {$this.{Check Zero Page Enabled} = "not checked"}
			true {$this.{Check Zero Page Enabled} = "checked"}
		}

		[int64]$lmetaCap = $lunReceived.METACAPACITY
		$this.{Metadata Capacity} = $lmetaCap * $lSectorSize / 1GB

		$this.{DataDestruction Progress} = $lunReceived.PROGRESS

		switch ($lunReceived.READCACHEPOLICY)
		{
			1 {$this.{Read Cache Policy} = "permanent"}
			2 {$this.{Read Cache Policy} = "default"}
			3 {$this.{Read Cache Policy} = "reclaim"}
		}

		switch ($lunReceived.WRITECACHEPOLICY)
		{
			4 {$this.{Write Cache Policy} = "permanent"}
			5 {$this.{Write Cache Policy} = "default"}
			6 {$this.{Write Cache Policy} = "reclaim"}
		}

		switch ($lunReceived.ENABLESMARTDEDUP)
		{
			false {$this.{SmartDedupe Enabled} = "disabled"}
			true {$this.{SmartDedupe Enabled} = "enabled"}
		}

		switch ($lunReceived.ENABLEDEDUP)
		{
			false {$this.{Deduplication Enabled} = "disabled"}
			true {$this.{Deduplication Enabled} = "enabled"}
		}

		switch ($lunReceived.ENABLEDEDUPCHECK)
		{
			false {$this.{Deduplication Check Enabled} = "disabled"}
			true {$this.{Deduplication Check Enabled} = "enabled"}
		}

		switch ($lunReceived.ENABLECOMPRESSION)
		{
			false {$this.{Compression Enabled} = "disabled"}
			true {$this.{Compression Enabled} = "enabled"}
		}

		switch ($lunReceived.COMPRESSION)
		{
			0 {$this.{Compression Algorithm} = "rapid"}
			1 {$this.{Compression Algorithm} = "deep"}
		}

		$this.{Deduplication Saved Ratio} = $lunReceived.DEDUPSAVEDRATIO
		$this.{Compression Saved Ratio} = $lunReceived.COMPRESSIONSAVEDRATIO
		$this.{Total Saved Ratio} = $lunReceived.TOTALSAVEDRATIO

		[int64]$ldedupSavCap = $lunReceived.DEDUPSAVEDCAPACITY
		$this.{Dedupe Saved Capacity} = $ldedupSavCap * $lSectorSize / 1GB

		[int64]$lcompSavCap = $lunReceived.COMPRESSIONSAVEDCAPACITY
		$this.{Compression Saved Capacity} = $lcompSavCap * $lSectorSize / 1GB

		[int64]$ltotalSavCap = $lunReceived.TOTALSAVEDCAPACITY
		$this.{Total Saved Capacity} = $ltotalSavCap * $lSectorSize / 1GB

		[int64]$lConsumerCap = $lunReceived.usedConsumerDataCapacity
		$this.{Total Consumer Space} = $lConsumerCap * $lSectorSize / 1GB

		$this.{vStore Id} = $lunReceived.vStoreId
		$this.{vStore Name} = $lunReceived.vstoreName

	}
}