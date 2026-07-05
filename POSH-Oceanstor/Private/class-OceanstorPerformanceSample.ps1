function New-DMPerformanceSample {
    <#
    .SYNOPSIS
        Builds a OceanStor.PerformanceSample display object from a resolved performance_data entry.

    .DESCRIPTION
        A PS class is awkward here because the set of metric properties on the object varies
        per-call (whatever -Metric values the caller requested on Get-DMPerformance), so this is a
        factory function producing a [pscustomobject] instead of a class instance. A raw metric
        value of exactly -1 is treated as an array "not applicable to this object type" sentinel
        and surfaced as $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ObjectType,

        [Parameter(Mandatory = $true)]
        [string]$ObjectId,

        [Parameter(Mandatory = $true)]
        [datetime]$Timestamp,

        [Parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary]$Metrics,

        [object[]]$RawIndicators,

        [object[]]$RawValues,

        [object]$Session
    )

    $sample = [ordered]@{
        PSTypeName = 'OceanStor.PerformanceSample'
        ObjectType = $ObjectType
        ObjectId   = $ObjectId
        Timestamp  = $Timestamp
    }

    $metricNames = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $Metrics.Keys) {
        $value = $Metrics[$key]
        if ($null -ne $value -and [double]$value -eq -1) {
            $value = $null
        }
        $sample[$key] = $value
        $metricNames.Add($key)
    }

    $result = [pscustomobject]$sample

    Add-Member -InputObject $result -MemberType NoteProperty -Name RawIndicators -Value $RawIndicators
    Add-Member -InputObject $result -MemberType NoteProperty -Name RawValues -Value $RawValues
    Add-Member -InputObject $result -MemberType NoteProperty -Name Session -Value $Session

    $defaultDisplaySet = @('ObjectId', 'Timestamp') + @($metricNames)
    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultDisplaySet)
    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)
    $result | Add-Member MemberSet PSStandardMembers $standardMembers -Force

    return $result
}
