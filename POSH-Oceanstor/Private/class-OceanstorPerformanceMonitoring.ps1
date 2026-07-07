function New-DMPerformanceMonitoringStatus {
    <#
    .SYNOPSIS
        Builds a OceanStor.PerformanceMonitoringStatus display object from the switch + strategy
        performance_statistic_switch / performance_statistic_strategy GET responses.

    .DESCRIPTION
        Uses the same factory-function convention as New-DMPerformanceSample for consistency,
        even though this object's property set is static (no per-call dynamic metrics).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Switch,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Strategy,

        [object]$Session
    )

    $result = [pscustomobject][ordered]@{
        PSTypeName              = 'OceanStor.PerformanceMonitoringStatus'
        Enabled                 = [bool][int]$Switch.CMO_PERFORMANCE_SWITCH
        BeginTime               = $Switch.CMO_PERFORMANCE_BEGIN_TIME
        SamplingIntervalSeconds = [int]$Strategy.CMO_STATISTIC_INTERVAL
        ArchiveEnabled          = [bool][int]$Strategy.CMO_STATISTIC_ARCHIVE_SWITCH
        ArchiveIntervalSeconds  = [int]$Strategy.CMO_STATISTIC_ARCHIVE_TIME
        AutoStop                = [bool][int]$Strategy.CMO_STATISTIC_AUTO_STOP
        MaxDays                 = [int]$Strategy.CMO_STATISTIC_MAX_TIME
    }

    Add-Member -InputObject $result -MemberType NoteProperty -Name Session -Value $Session

    $defaultDisplaySet = @('Enabled', 'SamplingIntervalSeconds', 'ArchiveEnabled', 'ArchiveIntervalSeconds', 'AutoStop', 'MaxDays')
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $result | Add-Member MemberSet PSStandardMembers $standardMembers -Force

    return $result
}
