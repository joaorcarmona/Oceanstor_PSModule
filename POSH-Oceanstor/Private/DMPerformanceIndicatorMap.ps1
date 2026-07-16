function Get-DMPerformanceIndicatorMap {
    <#
    .SYNOPSIS
        Returns the friendly-metric-name -> indicator-ID/unit map for OceanStor performance indicators.

    .DESCRIPTION
        Source: OceanStor Dorado 6.1.6 REST Interface Reference, appendix 5.4.1 (Block Storage
        Performance Indicators, as returned by the performance_data batch interface) and 5.4.3
        (File System Performance Indicators, the Ops/NAS entries). Latency/service-time
        indicators are reported by the array in microseconds; Ms-suffixed friendly names convert
        on output, Us-suffixed names keep the raw microsecond value. NAS response-time indicators
        are only exposed with the Us suffix because their live unit is unconfirmed.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        TotalIOPS           = @{ Id = 22;  Unit = 'IO/s' }
        ReadIOPS            = @{ Id = 25;  Unit = 'IO/s' }
        WriteIOPS           = @{ Id = 28;  Unit = 'IO/s' }
        BandwidthMBps       = @{ Id = 21;  Unit = 'MB/s' }
        ReadBandwidthMBps   = @{ Id = 23;  Unit = 'MB/s' }
        WriteBandwidthMBps  = @{ Id = 26;  Unit = 'MB/s' }
        AvgLatencyMs        = @{ Id = 370; Unit = 'ms'; SourceUnit = 'us' }
        ReadLatencyMs       = @{ Id = 384; Unit = 'ms'; SourceUnit = 'us' }
        WriteLatencyMs      = @{ Id = 385; Unit = 'ms'; SourceUnit = 'us' }
        AvgLatencyUs        = @{ Id = 370; Unit = 'us' }
        ReadLatencyUs       = @{ Id = 384; Unit = 'us' }
        WriteLatencyUs      = @{ Id = 385; Unit = 'us' }
        ServiceTimeUs       = @{ Id = 369; Unit = 'us' }
        AvgReadIOSizeKB     = @{ Id = 24;  Unit = 'KB' }
        AvgWriteIOSizeKB    = @{ Id = 27;  Unit = 'KB' }
        QueueLength         = @{ Id = 19;  Unit = 'count' }
        UsagePercent        = @{ Id = 18;  Unit = '%' }
        ReadCacheHitPercent = @{ Id = 93;  Unit = '%' }
        WriteCacheHitPercent = @{ Id = 95; Unit = '%' }
        CpuUsagePercent     = @{ Id = 68;  Unit = '%' }
        CacheUsagePercent   = @{ Id = 69;  Unit = '%' }
        Ops                 = @{ Id = 182; Unit = 'IO/s' }
        ReadOps             = @{ Id = 232; Unit = 'IO/s' }
        WriteOps            = @{ Id = 233; Unit = 'IO/s' }
        AvgIOSizeKB         = @{ Id = 228; Unit = 'KB' }
        AvgReadOpsResponseTimeUs  = @{ Id = 524; Unit = 'us' }
        AvgWriteOpsResponseTimeUs = @{ Id = 525; Unit = 'us' }
        NasServiceTimeUs    = @{ Id = 523; Unit = 'us' }
        ReadBandwidthKBps   = @{ Id = 123; Unit = 'KB/s' }
        WriteBandwidthKBps  = @{ Id = 124; Unit = 'KB/s' }
    }
}

function Get-DMPerformanceReportObjectTypeMap {
    <#
    .SYNOPSIS
        Returns the friendly-name -> report object-type map used by pms/report_task.

    .DESCRIPTION
        Each entry carries the report display Name and the numeric object-type Enum the
        documented report_task content[].object_type field expects (same enum space as
        performance_data's $script:DMPerformanceObjectTypeMap in Get-DMPerformance.ps1).
        Scoped to the object types the module already models; Snapshot and ReplicationPair
        are out of scope.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    # Name strings follow the documented content[].object_type values exactly
    # (REST Interface Reference, POST /api/v2/pms/report_task); the live array
    # rejects the request with 1073952264 when they differ.
    return [ordered]@{
        LUN          = @{ Name = 'LUN'; Enum = 11 }
        Controller   = @{ Name = 'CONTROLLER'; Enum = 207 }
        StoragePool  = @{ Name = 'STORAGEPOOL'; Enum = 216 }
        Disk         = @{ Name = 'DISK'; Enum = 10 }
        Host         = @{ Name = 'HOST'; Enum = 21 }
        System       = @{ Name = 'SYSTEM'; Enum = 201 }
        FCPort       = @{ Name = 'FC_PORT'; Enum = 212 }
        EthernetPort = @{ Name = 'ETH_PORT'; Enum = 213 }
        FileSystem   = @{ Name = 'FileSystem'; Enum = 40 }
    }
}

function Get-DMPerformanceReportTimeSegmentMap {
    <#
    .SYNOPSIS
        Returns the friendly-name -> API-string time_segment map used by pms/report_task.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        OneHour  = 'one_hour'
        OneDay   = 'one_day'
        OneWeek  = 'one_week'
        OneMonth = 'one_month'
        OneYear  = 'one_year'
        Customer = 'customer'
    }
}
