class OceanstorLunv6{
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
	[int64]${Thin Capacity Usage*}
	[int64]${Replication Capacity}
	[string]${Belong Lun Group}
	[string]${Remote Lun Id}
	[string]${Usage Type}
	[string]${Remote Lun WWN}
	[boolean]${Compression Enabled*}
	[boolean]${Deduplication Enabled*}
	[string]${Mirror Type}
	[string]${iSCSI Thin Lun Threshold}
	[boolean]${iSCSI Thin Lun Threshold Enabled}
	[string]${Lun Masq Status}
	[string]${Remote Array Masq ID}
	[string]${External DIF Support}
	[string]${Value Added Service Status}
	[string]${VASA DRS Enabled}
	[string]${VASA Capabilities}
	[string]${VASA Thin Lun Severity}
	[string]${Workload Type Id}
	[string]${Workload Type Name}
	[string]${Takeover Lun WWN}
	[string]${Snapshot Schedule Id}
	[string]${IO Class Id}
	[string]${IO Priority}
	[string]${Compression Algorithm*}
	[string]${Deduplication Saved Ratio*}
	[string]${Compression Saved Ratio*}
	[string]${Total Saved Ratio*}
	[int64]${Dedupe Saved Capacity*}
	[int64]${Compression Saved Capacity*}
	[int64]${Total Saved Capacity*}
	[string]${Is Clone}
	[string]${Consistency Group Id}
	[string]${HyperCDP Schedule Id}
	[string]${Mapped}
	[string]${HyperCDP Schedule Status}
	[string]${Mirror Policy}
	[boolean]${Show DedupCompression Switch}
	[string]${Grain Size}
	[string]${Check Zero Page Enabled}
	[string]${Lun FunctionType}
	[string]${Namespace GUID}
	[string]${SmartCache Partition Id}
	[string]${SmartCache Hit Rate}

	OceanstorLunv6 ([array]$LunReceived,[pscustomobject]$ObjStorage)
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
		$this.{Thin Capacity Usage*} = $lunReceived.THINCAPACITYUSAGE

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

		switch ($lunReceived.ENABLECOMPRESSION)
		{
			false {$this.{Compression Enabled*} = "disabled"}
			true {$this.{Compression Enabled*} = "enabled"}
		}

		switch ($lunReceived.ENABLESMARTDEDUP)
		{
			false {$this.{Deduplication Enabled*} = "disabled"}
			true {$this.{Deduplication Enabled*} = "enabled"}
		}

		switch ($lunReceived.MIRRORTYPE)
		{
			0 {$this.{Mirror Type} = "common LUN"}
			1 {$this.{Mirror Type} = "mirror LUN"}
			2 {$this.{Mirror Type} = "mirror copy LUN"}
		}

		$this.{iSCSI Thin Lun Threshold} = $lunReceived.ISCSITHINLUNTHRESHOLD

		switch ($lunReceived.ENABLEISCSITHINLUNTHRESHOLD)
		{
			false {$this.{iSCSI Thin Lun Threshold Enabled} = "off"}
			true {$this.{iSCSI Thin Lun Threshold Enabled} = "on"}
		}

		switch ($lunReceived.DISGUISESTATUS)
		{
			0 {$this.{Lun Masq Status} = "no masquerading"}
			1 {$this.{Lun Masq Status} = "basic masquerading"}
			2 {$this.{Lun Masq Status} = "extended masquerading"}
			3 {$this.{Lun Masq Status} = "inherited masquerading"}
			4 {$this.{Lun Masq Status} = "3rd-party masquerading"}
		}

		$this.{Remote Array Masq ID} = $lunReceived.DISGUISEREMOTEARRAYID

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

		$this.{Workload Type Id} = $lunReceived.WORKLOADTYPEID

		if ($lunReceived.WORKLOADTYPEID){
			$this.{Workload Type Name} = "invalid"
		} else {
			$this.{Workload Type Name} = $lunReceived.WORKLOADTYPENAME
		}

		$this.{Takeover Lun WWN} = $lunReceived.takeOverLunWwn
		$this.{Snapshot Schedule Id} = $lunReceived.SNAPSHOTSCHEDULEID
		$this.{IO Class Id} = $lunReceived.IOCLASSID

		switch ($lunReceived.IOPRIORITY)
		{
			1 {$this.{IO Priority} = "low"}
			2 {$this.{IO Priority} = "medium"}
			3 {$this.{IO Priority} = "lhigh"}
		}

		switch ($lunReceived.COMPRESSION)
		{
			0 {$this.{Compression Algorithm*} = "rapid"}
			1 {$this.{Compression Algorithm*} = "deep"}
		}
		$this.{Deduplication Saved Ratio*} = $lunReceived.DEDUPSAVEDRATIO
		$this.{Compression Saved Ratio*} = $lunReceived.COMPRESSIONSAVEDRATIO
		$this.{Total Saved Ratio*} = $lunReceived.TOTALSAVEDRATIO

		[int64]$ldedupSavCap = $lunReceived.DEDUPSAVEDCAPACITY
		$this.{Dedupe Saved Capacity*} = $ldedupSavCap * $lSectorSize / 1GB

		[int64]$lcompSavCap = $lunReceived.COMPRESSIONSAVEDCAPACITY
		$this.{Compression Saved Capacity*} = $lcompSavCap * $lSectorSize / 1GB

		[int64]$ltotalSavCap = $lunReceived.TOTALSAVEDCAPACITY
		$this.{Total Saved Capacity*} = $ltotalSavCap * $lSectorSize / 1GB

		switch ($lunReceived.ISCLONE)
		{
			false {$this.{Is Clone} = "no"}
			true {$this.{Is Clone} = "yes"}
		}
		$this.{Consistency Group Id} = $lunReceived.lunCgId
		$this.{HyperCDP Schedule Id} = $lunReceived.hyperCdpScheduleId

		switch ($lunReceived.mapped)
		{
			false {$this.{Mapped} = "no"}
			true {$this.{Mapped} = "yes"}
		}

		switch ($lunReceived.HYPERCDPSCHEDULEDISABLE)
		{
			0 {$this.{HyperCDP Schedule Status} = "enabled"}
			1 {$this.{HyperCDP Schedule Status} = "disabled"}
		}

		switch ($lunReceived.MIRRORPOLICY)
		{
			0 {$this.{Mirror Policy} = "no mirroring"}
			1 {$this.{Mirror Policy} = "mirroring"}
		}

		switch ($lunReceived.isShowDedupAndCompression)
		{
			0 {$this.{Show DedupCompression Switch} = $false}
			1 {$this.{Show DedupCompression Switch} = $true}
		}
		$this.{Grain Size} = $lunReceived.grainSize

		switch ($lunReceived.ISCHECKZEROPAGE)
		{
			false {$this.{Check Zero Page Enabled} = "not checked"}
			true {$this.{Check Zero Page Enabled} = "checked"}
		}

		switch ($lunReceived.functionType)
		{
			1 {$this.{Lun FunctionType} = "LUN"}
			2 {$this.{Lun FunctionType} = "Snapshot"}
			3 {$this.{Lun FunctionType} = "Clone"}
		}

		$this.{Namespace GUID} = $lunReceived.NGUID
		$this.{SmartCache Partition Id} = $lunReceived.SMARTCACHEPARTITIONID
		$this.{SmartCache Hit Rate} = $lunReceived.SC_HITRAGE

	}
}