function Get-DMPerformanceIndicatorMap {
    <#
    .SYNOPSIS
        Returns the friendly-metric-name -> indicator-ID/unit map for OceanStor performance indicators.

    .DESCRIPTION
        Source: OceanStor Dorado 6.1.6 REST Interface Reference, appendix 5.4.1 (Block Storage
        Performance Indicators, as returned by the performance_data batch interface). Latency/
        service-time indicators are reported by the array in microseconds; Ms-suffixed friendly
        names convert on output, Us-suffixed names keep the raw microsecond value.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
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
    }
}

function Get-DMPerformanceReportObjectTypeMap {
    <#
    .SYNOPSIS
        Returns the friendly-name -> API-string object_type map used by pms/report_task.

    .DESCRIPTION
        The report_task interface encodes object_type as a name string (e.g. 'FC_PORT'),
        unlike performance_data's numeric object_type (see $script:DMPerformanceObjectTypeMap
        in Get-DMPerformance.ps1). Scoped to the object types the module already models;
        Snapshot and ReplicationPair are out of scope.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        LUN          = 'LUN'
        Controller   = 'CONTROLLER'
        StoragePool  = 'STORAGEPOOL'
        Disk         = 'DISK'
        Host         = 'HOST'
        System       = 'SYSTEM'
        FCPort       = 'FC_PORT'
        EthernetPort = 'ETH_PORT'
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
