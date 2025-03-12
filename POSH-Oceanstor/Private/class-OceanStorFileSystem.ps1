class OceanstorFileSystem{
    [string]${Id}
    [string]${Name}
    [string]${Parent ID}
    [string]${Parent Name}
    [string]${Parent Snapshot ID}
    [string]${Parent Type}
    [string]${Actual File System Type}
    [int64]${Allocated Pool Quota}
    [int64]${Allocation Capacity}
    [string]${Allocation Type}
    [string]${AlternateDataStreams}
    [string]${Application Scenario}
    [boolean]${Atime}
    [boolean]${Auto Delete Snapshot Enable}
    [string]${Auto Grow Threshold}
    [string]${Auto Lock Time unit}
    [string]${Auto Shrink Threshold}
    [string]${Auto Size Enable}
    [int64]${Auto Size Increment}
    [int64]${Available And Allocation Capacity Ratio}
    [int64]${Available Capacity}
    [string]${Cache Patition Id}
    [string]${Capability}
    [int64]${Capacity}
    [string]${Capacity Threshold}
    [boolean]${Case Preserved}
    [boolean]${Case Sensitive}
    [boolean]${Checksum Enable}
    [int64]${Children Clone FS Number}
    [string]${Compression Type}
    [int64]${Compression Saved Capacity}
    [int64]${Compression Saved Ratio}
    [string]${DataTransferPolicy}
    [int64]${Dedup Saved Capacity}
    [int64]${Dedup Saved Ratio}
    [string]${DefaultProtectionTimeUnit}
    [string]${Description}
    [boolean]${Enable Compression}
    [boolean]${Enable Dedupe}
    [string]${Enable Dedupe Check}
    [boolean]${Enable Rollback Mode}
    [boolean]${Enable Timing Snapshot}
    [string]${Health Status}
    [string]${Hypermetro Pair Ids}
    [string]${Hypervault Pair Ids}
    [int64]${Initial Allocated Capacity}
    [string]${Initial Allocation Policy}
    [int64]${Inode Total Count}
    [int64]${Inode Total Used}
    [string]${IOClassId}
    [string]${IO Priority}
    [boolean]${IS Clone FS}
    [string]${Is Delete Parent Snapshot}
    [boolean]${IS Snap Dir Visible}
    [string]${IS Support Auto Tier}
    [string]${Local Access Definition Required}
    [int64]${Max Auto Size}
    [int64]${Max Filename Lenght}
    [string]${Max Protect Time Unit}
    [int64]${Minimum Auto Size}
    [string]${Minimum Protect Time Unit}
    [int64]${Minimum Size FS Capacity}
    [string]${Owning Controller}
    [string]${Parent FileSystem Name}
    [string]${Path Name Separator String}
    [boolean]${Read Only}
    [string]${Recycle Bin}
    [string]${Remote Replication Ids}
    [string]${Root}
    [string]${Running Status}
    [string]${Read Write Status}
    [int64]${Smartcache Size}
    [string]${Smartcache Hit Rate}
    [int64]${Sector Size}
    [string]${Smartcache Partition Id}
    [string]${Smartcache State}
    [string]${SmartTier Config}
    [int64]${Snapshot Reserve Capacity}
    [string]${Snapshot Reserve Per}
    [int64]${Snapshot Use Capacity}
    [string]${Space Recycle Mode}
    [string]${Space Self Adjusting Mode}
    [string]${Split Enable}
    [string]${Split Progress}
    [string]${Split Speed}
    [string]${Split Status}
    [string]${SSD Capacity Upper Limit}
    [string]${SubType}
    [int64]${Tier Count}
    [int64]${Timing Snapshot Max Number}
    [string]${Timing Snapshot Schedule ID}
    [int64]${Total Saved Capacity}
    [int64]${Total Saved Ratio}
    [string]${Type}
    [string]${Used SSD Capacity}
    [string]${Working Controller}
    [boolean]${Worm Auto Delete}
    [boolean]${Worm Auto Lock}
    [string]${Worm Auto Lock Time}
    [string]${Worm Clock Time}
    [string]${Worm Def Protect Period}
    [string]${Worm Experied Time}
    [string]${Worm Max Protect Period}
    [string]${Worm Min Protect Period}
    [string]${Worm Type}
    [boolean]${Write Check}

    OceanstorFileSystem ([array]$FileSystem)
    {  
        [int64]$fSector = 512
        $this.{Sector Size} = $FileSystem.SECTORSIZE
        
        switch($FileSystem.ACTUALFILESYSTEMTYPE)
		{
			0 {$this.{Actual File System Type} = "Wushan FS"}
            1 {$this.{Actual File System Type}  = "NOFS"}
		}

        $this.{Allocated Pool Quota} = $FileSystem.allocatedPoolQuota
        
        if ($FileSystem.ALLOCCAPACITY -eq "0")
        {
            $this.{Allocation Capacity} = "0"
        } else {
            $this.{Allocation Capacity} = $FileSystem.ALLOCCAPACITY / $this.{Sector Size} / 1GB
        }   
        
        $this.{Allocation Type} = $FileSystem.ALLOCTYPE

        switch($FileSystem.ALLOCTYPE)
		{
			0 {$this.{Allocation Type} = "Thick"}
			1 {$this.{Allocation Type} = "Thin"}
		}

        switch($FileSystem.ALTERNATEDATASTREAMS)
		{
			0 {$this.{AlternateDataStreams} = "no"}
            1 {$this.{AlternateDataStreams} = "yes"}
		}

        switch($FileSystem.APPLICATIONSCENARIO)
		{
			1 {$this.{Application Scenario} = "Database"}
			2 {$this.{Application Scenario} = "VM"}
            3 {$this.{Application Scenario} = "User-defined"}
		}

        if ($FileSystem.ATIME -eq "TRUE")
        {
            $this.{Atime} = $true
        } else {
            $this.{Atime} = $false
        }

        if ($FileSystem.AUTODELSNAPSHOTENABLE -eq "TRUE")
        {
            $this.{Auto Delete Snapshot Enable}  = $true
        } else {
            $this.{Auto Delete Snapshot Enable} = $false
        }

        $this.{Auto Delete Snapshot Enable} = $FileSystem.AUTODELSNAPSHOTENABLE
        $this.{Auto Grow Threshold} = $FileSystem.AUTOGROWTHRESHOLDPERCENT

        switch($FileSystem.AUTOLOCKTIMEUNIT)
		{
			46 {$this.{Auto Lock Time unit} = "day"}
            47 {$this.{Auto Lock Time unit} = "month"}
            48 {$this.{Auto Lock Time unit} = "year"}
		}

        $this.{Auto Shrink Threshold} = $FileSystem.AUTOSHRINKTHRESHOLDPERCENT

        if ($FileSystem.AUTOSIZEENABLE -eq "TRUE")
        {
            $this.{Auto Size Enable}  = $true
        } else {
            $this.{Auto Size Enable} = $false
        }

        $this.{Auto Size Increment} = $FileSystem.AUTOSIZEINCREMENT
        $this.{Available And Allocation Capacity Ratio} = $FileSystem.AVAILABLEANDALLOCCAPACITYRATIO

        if ($FileSystem.AVAILABLECAPCITY -eq "0")
        {
            $this.{Available Capacity} = "0"
        } else {
            $this.{Available Capacity} = $FileSystem.AVAILABLECAPCITY / $fSector/ 1GB
        }

        $this.{Cache Patition Id} = $FileSystem.CACHEPARTITIONID

        switch($FileSystem.CAPABILITY)
		{
			0 {$this.{Capability} = "No Protection"}
            1 {$this.{Capability} = "Based on Capacity"}
            2 {$this.{Capability} = "Based on High Performance"}
            3 {$this.{Capability} = "Based on Tiers"}
		}

        [int64]$fCapacity = $FileSystem.CAPACITY
        [int64]$fscapacity = $fCapacity * $fSector / 1GB
        $this.{Capacity} = $fscapacity
        
        $this.{Capacity Threshold} = $FileSystem.CAPACITYTHRESHOLD

        if ($FileSystem.CASEPRESERVED -eq "TRUE")
        {
            $this.{Case Preserved} = $true
        } else {
            $this.{Case Preserved}= $false
        }

        if ($FileSystem.CASESENSITIVE -eq "TRUE")
        {
            $this.{Case Sensitive} = $true
        } else {
            $this.{Case Sensitive} = $false
        }

        if ($FileSystem.CHECKSUMENABLE -eq "TRUE")
        {
            $this.{Checksum Enable} = $true
        } else {
            $this.{Checksum Enable}  = $false
        }

        $this.{Children Clone FS Number} = $FileSystem.CHILDRENCLONEFSNUM

        switch($FileSystem.COMPRESSION)
		{
			0 {$this.{Compression Type} = "Rapid"}
            1 {$this.{Compression Type}  = "Deep"}
		}

        $this.{Compression Saved Capacity} = $FileSystem.COMPRESSIONSAVEDCAPACITY / $fSector / 1GB
        $this.{Compression Saved Ratio} = $FileSystem.COMPRESSIONSAVEDRATIO

        switch($FileSystem.DATATRANSFERPOLICY)
		{
			0 {$this.{DataTransferPolicy} = "No Migration"}
            1 {$this.{DataTransferPolicy} = "Automatic Migration"}
            2 {$this.{DataTransferPolicy} = "Migrate to Higher Tier"}
            3 {$this.{DataTransferPolicy} = "Migrate to Lower Tier"}
		}

        $this.{Dedup Saved Capacity} = $FileSystem.DEDUPSAVEDCAPACITY / $fSector / 1GB
        $this.{Dedup Saved Ratio} = $FileSystem.DEDUPSAVEDRATIO

        switch($FileSystem.DEFPROTECTTIMEUNIT)
		{
			46 {$this.{DefaultProtectiontimeUnit} = "day"}
            47 {$this.{DefaultProtectiontimeUnit} = "month"}
            48 {$this.{DefaultProtectiontimeUnit} = "year"}
		}

        $this.{Description} = $FileSystem.DESCRIPTION

        if ($FileSystem.ENABLECOMPRESSION -eq "TRUE")
        {
            $this.{Enable Compression} = $true
        } else {
            $this.{Enable Compression} = $false
        }

        if ($FileSystem.ENABLEDEDUP -eq "TRUE")
        {
            $this.{Enable Dedupe}  = $true
        } else {
            $this.{Enable Dedupe}  = $false
        }

        $this.{Enable Dedupe Check} = $FileSystem.ENABLEDEDUPCHECK

        if ($FileSystem.ENABLEROLLBACKMODE -eq "TRUE")
        {
            $this.{Enable Rollback Mode} = $true
        } else {
            $this.{Enable Rollback Mode} = $false
        }

        if ($FileSystem.ENABLETIMINGSNAPSHOT -eq "TRUE")
        {
            $this.{Enable Timing Snapshot}  = $true
        } else {
            $this.{Enable Timing Snapshot}  = $false
        }

        switch($FileSystem.HEALTHSTATUS)
		{
			1 {$this.{Health Status}   = "normal"}
		}

        $this.{Hypermetro Pair Ids} = $FileSystem.HYPERMETROPAIRIDS
        $this.{Hypervault Pair Ids} = $FileSystem.HYPERVAULTPAIRIDS
        $this.{Id} = $FileSystem.ID
        $this.{Initial Allocated Capacity} = $FileSystem.INITIALALLOCCAPACITY  / $fSector / 1GB

        switch($FileSystem.INITIALDISTRIBUTEPOLICY)
		{
			0 {$this.{Initial Allocation Policy}= "Automatic"}
            1 {$this.{Initial Allocation Policy} = "Highest Performance"}
            2 {$this.{Initial Allocation Policy} = "Performance"}
            3 {$this.{Initial Allocation Policy} = "Capacity"}
		}

        $this.{Inode Total Count} = $FileSystem.inodeTotalCount
        $this.{Inode Total Used} = $FileSystem.inodeUsedCount
        $this.{IOClassId} = $FileSystem.IOCLASSID

        switch($FileSystem.IOPRIORITY)
		{
			1 {$this.{IO Priority}  = "low"}
            2 {$this.{IO Priority}   = "middle"}
            3 {$this.{IO Priority}  = "high"}
		}

        if ($FileSystem.ISCLONEFS -eq "TRUE")
        {
            $this.{IS Clone FS} = $true
        } else {
            $this.{IS Clone FS}  = $false
        }

        if ($FileSystem.ISDELETEPARENTSNAPSHOT -eq "TRUE")
        {
            $this.{Is Delete Parent Snapshot} = $true
        } else {
            $this.{Is Delete Parent Snapshot}= $false
        }

        if ($FileSystem.ISSHOWSNAPDIR -eq "TRUE")
        {
            $this.{IS Snap Dir Visible}  = $true
        } else {
            $this.{IS Snap Dir Visible}  = $false
        }

        $this.{IS Support Auto Tier} = $FileSystem.ISSUPPORTAUTOTIER
        #TODO
        $this.{Local Access Definition Required} = $FileSystem.LOCALACCESSDEFINITIONREQUIRED
        $this.{Max Auto Size} = $FileSystem.MAXAUTOSIZE
        $this.{Max Filename Lenght} = $FileSystem.MAXFILENAMELENGTH

        switch($FileSystem.MAXPROTECTTIMEUNIT)
		{
			46 {$this.{Max Protect Time Unit} = "day"}
            47 {$this.{Max Protect Time Unit} = "month"}
            48 {$this.{Max Protect Time Unit} = "year"}
		}

        $this.{Minimum Auto Size} = $FileSystem.MINAUTOSIZE

        switch($FileSystem.MINPROTECTTIMEUNIT)
		{
			46 {$this.{Minimum Protect Time Unit} = "day"}
            47 {$this.{Minimum Protect Time Unit} = "month"}
            48 {$this.{Minimum Protect Time Unit} = "year"}
		}

        $this.{Minimum Size FS Capacity} = $FileSystem.MINSIZEFSCAPACITY / $fSector / 1GB
        $this.{Name} = $FileSystem.NAME
        $this.{Owning Controller} = $FileSystem.OWNINGCONTROLLER
        $this.{Parent FileSystem Name} = $FileSystem.PARENTFILESYSTEMNAME
        $this.{Parent ID} = $FileSystem.PARENTID
        $this.{Parent Name} = $FileSystem.PARENTNAME
        $this.{Parent Snapshot ID} = $FileSystem.PARENTSNAPSHOTID

        switch($FileSystem.PARENTTYPE)
		{
			216 {$this.{Parent Type} = "Storage Pool"}
		}

        $this.{Path Name Separator String} = $FileSystem.PATHNAMESEPARATORSTRING

        if ($FileSystem.READONLY -eq "TRUE")
        {
            $this.{Read Only} = $true
        } else {
            $this.{Read Only} = $false
        }

        switch($FileSystem.RECYCLESWITCH)
		{
			0 {$this.{Recycle Bin} = $false}
			1 {$this.{Recycle Bin} = $true}
		}

        $this.{Remote Replication Ids} = $FileSystem.REMOTEREPLICATIONIDS
        $this.{Root} = $FileSystem.ROOT

        switch($FileSystem.RUNNINGSTATUS)
		{
			27 {$this.{Running Status}  = "Online"}
            28 {$this.{Running Status}  = "Offline"}
		}

        switch($FileSystem.rwStatus)
		{
			0 {$this.{Read Write Status} = "No Access"}
            1 {$this.{Read Write Status} = "Read Only"}
            3 {$this.{Read Write Status} = "Read and Write"}
		}

        $this.{Smartcache Size} = $FileSystem.SC_CACHEDSIZE
        $this.{Smartcache Hit Rate} = $FileSystem.SC_HITRAGE
        $this.{Smartcache Partition Id} = $FileSystem.SMARTCACHEPARTITIONID

        switch($FileSystem.SMARTCACHESTATE)
		{
			0 {$this.{Smartcache State} = "disabled"}
            1 {$this.{Smartcache State} = "enabled"}
            2 {$this.{Smartcache State} = "pool status inherited"}
		}

        $this.{SmartTier Config} = $FileSystem.SMARTTIERCONFIG
        $this.{Snapshot Reserve Capacity} = $FileSystem.SNAPSHOTRESERVECAPACITY
        $this.{Snapshot Reserve Per} = $FileSystem.SNAPSHOTRESERVEPER
        $this.{Snapshot Use Capacity} = $FileSystem.SNAPSHOTUSECAPACITY / $fSector / 1GB

        switch($FileSystem.SPACERECYCLEMODE)
		{
			0 {$this.{Space Recycle Mode} = "Auto Size"}
            1 {$this.{Space Recycle Mode} = "Delete Snapshot"}
		}

        switch($FileSystem.SPACESELFADJUSTINGMODE)
		{
			0 {$this.{Space Self Adjusting Mode} = "off"}
            1 {$this.{Space Self Adjusting Mode} = "grow"}
            2 {$this.{Space Self Adjusting Mode} = "grow shrink"}
		}

        switch($FileSystem.SPLITENABLE)
		{
			true {$this.{Split Enable} = "start splitting"}
            false {$this.{Split Enable} = "stop splitting"}
		}

        $this.{Split Progress} = $FileSystem.SPLITPROGRESS

        switch($FileSystem.SPLITSPEED)
		{
			1 {$this.{Split Speed} = "low"}
            2 {$this.{Split Speed} = "medium"}
            3 {$this.{Split Speed} = "high"}
            4 {$this.{Split Speed} = "highest"}
		}

        switch($FileSystem.SPLITSTATUS)
		{
			1 {$this.{Split Status} = "not start"}
            2 {$this.{Split Status} = "splitting"}
            3 {$this.{Split Status} = "queuing"}
            4 {$this.{Split Status} = "abnormal"}
		}

        $this.{SSD Capacity Upper Limit} = $FileSystem.SSDCAPACITYUPPERLIMIT

        switch($FileSystem.SUBTYPE)
		{
			27 {$this.{SubType} = "Common File System"}
            28 {$this.{SubType} = "WORM File System"}
		}

        $this.{Tier Count} = $FileSystem.tierCnt
        $this.{Timing Snapshot Max Number} = $FileSystem.TIMINGSNAPSHOTMAXNUM
        $this.{Timing Snapshot Schedule ID} = $FileSystem.TIMINGSNAPSHOTSCHEDULEID
        $this.{Total Saved Capacity} = $FileSystem.TOTALSAVEDCAPACITY
        $this.{Total Saved Ratio} = $FileSystem.TOTALSAVEDRATIO
        $this.{Type} = $FileSystem.TYPE
        $this.{Used SSD Capacity} = $FileSystem.USEDSSDCAPACITY
        $this.{Working Controller} = $FileSystem.WORKINGCONTROLLER

        if ($FileSystem.WORMAUTODEL -eq "TRUE")
        {
            $this.{Worm Auto Delete} = $true
        } else {
            $this.{Worm Auto Delete} = $false
        }

        $this.{Worm Auto Lock} = $FileSystem.WORMAUTOLOCK
        $this.{Worm Auto Lock Time} = $FileSystem.WORMAUTOLOCKTIME
        $this.{Worm Clock Time} = $FileSystem.WORMCLOCKTIME
        $this.{Worm Def Protect Period} = $FileSystem.WORMDEFPROTECTPERIOD
        $this.{Worm Experied Time} = $FileSystem.WORMEXPIREDTIME
        $this.{Worm Max Protect Period} = $FileSystem.WORMMAXPROTECTPERIOD
        $this.{Worm Min Protect Period} = $FileSystem.WORMMINPROTECTPERIOD

        switch($FileSystem.WORMTYPE)
		{
			1 {$this.{Worm Type}= "Compliance"}
            3 {$this.{Worm Type} = "Enterprise"}
		}

        if ($FileSystem.WRITECHECK -eq "TRUE")
        {
            $this.{Write Check} = $true
        } else {
            $this.{Write Check} = $false
        }
    }
}