class OceanStorStoragePool {
    hidden [pscustomobject]${Session}
    hidden [pscustomobject]${WebSession}

    # Identity and status
    [string]$id
    [string]$name
    [string]$type
    ${Health Status}
    ${Running Status}
    ${Parent Id}
    ${Parent Name}
    ${Parent Type}
    [string]$description
    ${Usage Type}
    ${Container Enabled}
    ${Auto Delete}

    # Tier composition (only tier 0 is populated on all-flash Dorado; tier 1/2 capacity
    # return the uint64 "invalid" sentinel when unused, which is normalised to $null below)
    ${Tier0 Disk Type}
    ${Tier0 RAID Level}
    ${Tier0 Capacity (GB)}
    ${Tier1 Capacity (GB)}
    ${Tier2 Capacity (GB)}

    # Capacity (all raw values are in 512-byte sectors and converted to GB)
    ${Total Capacity (GB)}
    ${Free Capacity (GB)}
    ${Used Capacity (GB)}
    ${Used Capacity Percent}
    ${Used Capacity Threshold Percent}
    ${Used Capacity Without Meta (GB)}
    ${Allocated Data Capacity (GB)}
    ${Available For LUN (GB)}
    ${LUN Configured Capacity (GB)}
    ${LUN Mapped Capacity (GB)}
    ${LUN Write Capacity (GB)}
    ${Replication Capacity (GB)}
    ${Subscribed Capacity (GB)}
    ${Used Subscribed Capacity (GB)}
    ${Total FS Capacity (GB)}
    ${FS Subscribed Capacity (GB)}
    ${FS Used Capacity (GB)}
    ${FS Shared Capacity (GB)}
    ${Protect Size (GB)}

    # Data reduction (ratios are JSON {numerator,denominator,logic} converted to "X:1")
    ${Compression Ratio}
    ${Deduplication Ratio}
    ${Space Reduction Ratio}
    ${Save Capacity Ratio}
    ${Thin Provision Save}
    ${FS Compression Ratio}
    ${FS Deduplication Ratio}
    ${FS Space Reduction Ratio}
    ${LUN Compression Ratio}
    ${LUN Deduplication Ratio}
    ${LUN Space Reduction Ratio}
    ${Compressed Capacity (GB)}
    ${Compress Involved Capacity (GB)}
    ${Deduped Capacity (GB)}
    ${Dedup Involved Capacity (GB)}
    ${Reduction Involved Capacity (GB)}

    # Provisioning and thresholds
    ${Provisioning Limit Switch}
    ${Provisioning Limit Percent}
    ${Ending Up Threshold Percent}
    ${Pool Protect Low Threshold Percent}
    ${Pool Protect High Threshold Percent}

    # Convert a capacity expressed in 512-byte sectors to GB, returning $null for an empty
    # value or the uint64 "invalid" sentinel (18446744073709551615) the array uses for
    # unpopulated tier capacities.
    hidden [object] ToGB([object]$sectors) {
        if ($null -eq $sectors -or "$sectors" -eq '') { return $null }
        [uint64]$v = 0
        if (-not [uint64]::TryParse("$sectors", [ref]$v)) { return $null }
        if ($v -eq [uint64]::MaxValue) { return $null }
        return [math]::Round(($v * 512.0) / 1GB, 2)
    }

    # Convert a data-reduction ratio JSON object ({numerator,denominator,logic}) to a
    # display string such as "1.1:1" or ">= 100:1". Returns $null when absent or unparsable.
    hidden [object] Ratio([object]$json) {
        if ($null -eq $json -or "$json" -eq '') { return $null }
        try {
            $r = "$json" | ConvertFrom-Json
            [double]$num = 0
            [double]$den = 0
            if (-not [double]::TryParse("$($r.numerator)", [ref]$num)) { return $null }
            if (-not [double]::TryParse("$($r.denominator)", [ref]$den)) { return $null }
            if ($den -eq 0) { return $null }
            # Format invariantly so a ratio always renders with a dot separator ("1.1:1"),
            # independent of the host's culture (e.g. pt-PT would otherwise produce "1,1:1").
            $value = [math]::Round($num / $den, 2).ToString([cultureinfo]::InvariantCulture)
            $prefix = ''
            if ($r.logic -and $r.logic -ne '=') { $prefix = "$($r.logic) " }
            return ('{0}{1}:1' -f $prefix, $value)
        }
        catch { return $null }
    }

    OceanStorStoragePool ([array]$spoolReceived, [pscustomobject]$WebSession) {
        $this.Session = $WebSession
        $this.WebSession = $WebSession
        $src = $spoolReceived[0]

        # Identity and status
        $this.id = $src.ID
        $this.name = $src.NAME
        $this.type = $src.TYPE
        $this.description = $src.DESCRIPTION
        $this.{Parent Id} = $src.PARENTID
        $this.{Parent Name} = $src.PARENTNAME

        switch ([string]$src.HEALTHSTATUS) {
            '1' { $this.{Health Status} = 'Normal' }
            '2' { $this.{Health Status} = 'Faulty' }
            '5' { $this.{Health Status} = 'Degraded' }
            default { $this.{Health Status} = $src.HEALTHSTATUS }
        }

        switch ([string]$src.RUNNINGSTATUS) {
            '14' { $this.{Running Status} = 'Pre-copy' }
            '16' { $this.{Running Status} = 'Rebuilt' }
            '27' { $this.{Running Status} = 'Online' }
            '28' { $this.{Running Status} = 'Offline' }
            '32' { $this.{Running Status} = 'Balancing' }
            '53' { $this.{Running Status} = 'Initializing' }
            '106' { $this.{Running Status} = 'Deleting' }
            default { $this.{Running Status} = $src.RUNNINGSTATUS }
        }

        switch ([string]$src.PARENTTYPE) {
            '266' { $this.{Parent Type} = 'Disk Domain' }
            default { $this.{Parent Type} = $src.PARENTTYPE }
        }

        switch ([string]$src.NEWUSAGETYPE) {
            '0' { $this.{Usage Type} = 'LUN and File System' }
            '1' { $this.{Usage Type} = 'LUN' }
            '2' { $this.{Usage Type} = 'File System' }
            default { $this.{Usage Type} = $src.NEWUSAGETYPE }
        }

        $this.{Container Enabled} = if ("$($src.ISCONTAINERENABLE)" -eq 'true') { 'enabled' } else { 'disabled' }

        switch ([string]$src.autoDeleteSwitch) {
            '0' { $this.{Auto Delete} = 'off' }
            '1' { $this.{Auto Delete} = 'on' }
            default { $this.{Auto Delete} = $src.autoDeleteSwitch }
        }

        # Tier composition
        switch ([string]$src.TIER0DISKTYPE) {
            '0' { $this.{Tier0 Disk Type} = 'Not Available/Not Used' }
            '3' { $this.{Tier0 Disk Type} = 'SSD' }
            '10' { $this.{Tier0 Disk Type} = 'SSD SED' }
            '14' { $this.{Tier0 Disk Type} = 'NVMe SSD' }
            '16' { $this.{Tier0 Disk Type} = 'NVMe SSD SED' }
            default { $this.{Tier0 Disk Type} = $src.TIER0DISKTYPE }
        }

        switch ([string]$src.TIER0RAIDLV) {
            '0' { $this.{Tier0 RAID Level} = 'Not Available/Not Used' }
            '2' { $this.{Tier0 RAID Level} = 'RAID 5' }
            '5' { $this.{Tier0 RAID Level} = 'RAID 6' }
            '11' { $this.{Tier0 RAID Level} = 'RAID-TP' }
            default { $this.{Tier0 RAID Level} = $src.TIER0RAIDLV }
        }

        $this.{Tier0 Capacity (GB)} = $this.ToGB($src.TIER0CAPACITY)
        $this.{Tier1 Capacity (GB)} = $this.ToGB($src.TIER1CAPACITY)
        $this.{Tier2 Capacity (GB)} = $this.ToGB($src.TIER2CAPACITY)

        # Capacity
        $this.{Total Capacity (GB)} = $this.ToGB($src.USERTOTALCAPACITY)
        $this.{Free Capacity (GB)} = $this.ToGB($src.USERFREECAPACITY)
        $this.{Used Capacity (GB)} = $this.ToGB($src.USERCONSUMEDCAPACITY)
        $this.{Used Capacity Percent} = $src.USERCONSUMEDCAPACITYPERCENTAGE
        $this.{Used Capacity Threshold Percent} = $src.USERCONSUMEDCAPACITYTHRESHOLD
        $this.{Used Capacity Without Meta (GB)} = $this.ToGB($src.USERCONSUMEDCAPACITYWITHOUTMETA)
        $this.{Allocated Data Capacity (GB)} = $this.ToGB($src.USERWRITEALLOCCAPACITY)
        $this.{Available For LUN (GB)} = $this.ToGB($src.DATASPACE)
        $this.{LUN Configured Capacity (GB)} = $this.ToGB($src.LUNCONFIGEDCAPACITY)
        $this.{LUN Mapped Capacity (GB)} = $this.ToGB($src.LUNMAPPEDCAPACITY)
        $this.{LUN Write Capacity (GB)} = $this.ToGB($src.TOTALLUNWRITECAPACITY)
        $this.{Replication Capacity (GB)} = $this.ToGB($src.REPLICATIONCAPACITY)
        $this.{Subscribed Capacity (GB)} = $this.ToGB($src.SUBSCRIBEDCAPACITY)
        $this.{Used Subscribed Capacity (GB)} = $this.ToGB($src.USEDSUBSCRIBEDCAPACITY)
        $this.{Total FS Capacity (GB)} = $this.ToGB($src.TOTALFSCAPACITY)
        $this.{FS Subscribed Capacity (GB)} = $this.ToGB($src.FSSUBSCRIBEDCAPACITY)
        $this.{FS Used Capacity (GB)} = $this.ToGB($src.FSUSEDCAPACITY)
        $this.{FS Shared Capacity (GB)} = $this.ToGB($src.FSSHAREDCAPACITY)
        $this.{Protect Size (GB)} = $this.ToGB($src.protectSize)

        # Data reduction
        $this.{Compression Ratio} = $this.Ratio($src.COMPRESSIONRATE)
        $this.{Deduplication Ratio} = $this.Ratio($src.DEDUPLICATIONRATE)
        $this.{Space Reduction Ratio} = $this.Ratio($src.SPACEREDUCTIONRATE)
        $this.{Save Capacity Ratio} = $this.Ratio($src.SAVECAPACITYRATE)
        $this.{Thin Provision Save} = $this.Ratio($src.THINPROVISIONSAVEPERCENTAGE)
        $this.{FS Compression Ratio} = $this.Ratio($src.fsCompressionRate)
        $this.{FS Deduplication Ratio} = $this.Ratio($src.fsDeduplicationRate)
        $this.{FS Space Reduction Ratio} = $this.Ratio($src.fsSpaceReductionRate)
        $this.{LUN Compression Ratio} = $this.Ratio($src.lunCompressionRate)
        $this.{LUN Deduplication Ratio} = $this.Ratio($src.lunDeduplicationRate)
        $this.{LUN Space Reduction Ratio} = $this.Ratio($src.lunSpaceReductionRate)
        $this.{Compressed Capacity (GB)} = $this.ToGB($src.COMPRESSEDCAPACITY)
        $this.{Compress Involved Capacity (GB)} = $this.ToGB($src.COMPRESSINVOLVEDCAPACITY)
        $this.{Deduped Capacity (GB)} = $this.ToGB($src.DEDUPEDCAPACITY)
        $this.{Dedup Involved Capacity (GB)} = $this.ToGB($src.DEDUPINVOLVEDCAPACITY)
        $this.{Reduction Involved Capacity (GB)} = $this.ToGB($src.REDUCTIONINVOLVEDCAPACITY)

        # Provisioning and thresholds
        $this.{Provisioning Limit Switch} = if ("$($src.PROVISIONINGLIMITSWITCH)" -eq 'true') { 'on' } else { 'off' }
        # A limit of -1 is returned as "invalid" when the provisioning-limit switch is off.
        $this.{Provisioning Limit Percent} = if ("$($src.PROVISIONINGLIMIT)" -eq '-1') { $null } else { $src.PROVISIONINGLIMIT }
        $this.{Ending Up Threshold Percent} = $src.ENDINGUPTHRESHOLD
        $this.{Pool Protect Low Threshold Percent} = $src.poolProtectLowThreshold
        $this.{Pool Protect High Threshold Percent} = $src.poolProtectHighThreshold
    }
}
