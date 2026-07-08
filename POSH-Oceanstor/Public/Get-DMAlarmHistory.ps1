function Get-DMAlarmHistory {
    <#
    .SYNOPSIS
        Queries Huawei OceanStor historical alarms and events.

    .DESCRIPTION
        Queries historical alarms and events via the OceanStor "Interface for
        Querying Historical Alarms and Events Information" (GET alarm/historyalarm,
        OceanStor Dorado 6.1.6 REST Interface Reference section 4.2.2.4.7).

        Unlike Get-DMAlarm (which only filters on alarm status and a time range),
        this cmdlet exposes the full documented server-side filter surface: level,
        alarm status, entry type (event/alarm/log), alarm object type, a specific
        alarm sequence number, and a sequence-number range. Friendly parameter
        values are mapped to the numeric API enum values documented in the
        reference, so callers never handle raw codes:

            Level        Info=2, Warning=3, Major=5, Critical=6
            AlarmStatus  Unrecovered=1, Cleared=2, Recovered=4
            Type         Event=0, Alarm=1, Cleared=2, OperationLog=3, RunLog=4, SecurityLog=10

        The alarm object-type catalog is dynamic per array, so -AlarmObjectType
        accepts a name (for example disk, LUN, port) which is resolved to its
        numeric value via Get-DMAlarmType before the query is issued.

        All filters are optional and are combined with a logical AND. Results are
        returned newest-first (sortby startTime,d) and fully paged.

    .PARAMETER WebSession
        Optional session to use on the REST call. If not defined, the module's
        cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Level
        Optional alarm severity filter. Valid values: Info, Warning, Major, Critical.

    .PARAMETER AlarmStatus
        Optional alarm status filter. Valid values: Unrecovered, Cleared, Recovered.

    .PARAMETER Type
        Optional entry-type filter. Valid values: Event, Alarm, Cleared,
        OperationLog, RunLog, SecurityLog.

    .PARAMETER AlarmObjectType
        Optional alarm object-type filter, given as a name from the array's alarm
        type catalog (see Get-DMAlarmType), for example disk, LUN, or port. The
        name is resolved to its numeric object-type value before querying. An
        unknown name is rejected with the list of valid names.

    .PARAMETER StartTime
        Optional. Only return entries generated at or after this time. Converted to
        a Unix epoch second and combined with -EndTime (defaulting to now) as a
        startTime:[start,end] range filter. Cannot be combined with -Last.

    .PARAMETER EndTime
        Optional. Only return entries generated at or before this time. Converted to
        a Unix epoch second and combined with -StartTime (defaulting to epoch 0) as
        a startTime:[start,end] range filter. Cannot be combined with -Last.

    .PARAMETER Last
        Optional convenience filter: return entries generated within this timespan of
        now. Equivalent to -StartTime ((Get-Date) - Last) -EndTime (Get-Date). Cannot
        be combined with -StartTime/-EndTime.

    .PARAMETER Sequence
        Optional. Return only the entry with this alarm sequence number (Alarm SN).

    .PARAMETER StartSequence
        Optional. Lower bound of an alarm sequence-number range filter (startSeq).

    .PARAMETER EndSequence
        Optional. Upper bound of an alarm sequence-number range filter (endSeq).

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        OceanStorAlarm

        Returns OceanStor alarm/event objects matching the supplied filters.

    .EXAMPLE
        PS C:\> Get-DMAlarmHistory -Level Critical

        Returns all historical critical-severity alarms and events.

    .EXAMPLE
        PS C:\> Get-DMAlarmHistory -Type Alarm -AlarmStatus Unrecovered

        Returns unrecovered alarms (excluding events and logs).

    .EXAMPLE
        PS C:\> Get-DMAlarmHistory -AlarmObjectType disk -Last (New-TimeSpan -Days 7)

        Returns disk-related entries generated in the last 7 days.

    .EXAMPLE
        PS C:\> Get-DMAlarmHistory -StartSequence 1000 -EndSequence 2000

        Returns entries whose alarm sequence number falls between 1000 and 2000.

    .NOTES
        Filename: Get-DMAlarmHistory.ps1
        Read-only.

    .LINK
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Major', 'Critical')]
        [string]$Level,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Unrecovered', 'Cleared', 'Recovered')]
        [string]$AlarmStatus,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Event', 'Alarm', 'Cleared', 'OperationLog', 'RunLog', 'SecurityLog')]
        [string]$Type,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$AlarmObjectType,

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime,

        [Parameter(Mandatory = $false)]
        [timespan]$Last,

        [Parameter(Mandatory = $false)]
        [Alias('Alarm SN', 'SN', 'AlarmSN')]
        [uint32]$Sequence,

        [Parameter(Mandatory = $false)]
        [Alias('startSeq')]
        [uint32]$StartSequence,

        [Parameter(Mandatory = $false)]
        [Alias('endSeq')]
        [uint32]$EndSequence
    )

    if ($Last -and ($PSBoundParameters.ContainsKey('StartTime') -or $PSBoundParameters.ContainsKey('EndTime'))) {
        throw '-Last cannot be combined with -StartTime or -EndTime.'
    }

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = 'Name', 'Level', 'Type', 'Alarm Status', 'Location', 'Start time'

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    # Map each friendly filter value to the numeric API enum value documented in
    # the reference (section 4.2.2.4.7). Clauses are collected and AND-joined.
    $clauses = New-Object System.Collections.Generic.List[string]

    if ($PSBoundParameters.ContainsKey('Level')) {
        $levelValue = switch ($Level) {
            'Info' { 2 }
            'Warning' { 3 }
            'Major' { 5 }
            'Critical' { 6 }
        }
        $clauses.Add("level::$levelValue")
    }

    if ($PSBoundParameters.ContainsKey('AlarmStatus')) {
        $statusValue = switch ($AlarmStatus) {
            'Unrecovered' { 1 }
            'Cleared' { 2 }
            'Recovered' { 4 }
        }
        $clauses.Add("alarmStatus::$statusValue")
    }

    if ($PSBoundParameters.ContainsKey('Type')) {
        $typeValue = switch ($Type) {
            'Event' { 0 }
            'Alarm' { 1 }
            'Cleared' { 2 }
            'OperationLog' { 3 }
            'RunLog' { 4 }
            'SecurityLog' { 10 }
        }
        $clauses.Add("type::$typeValue")
    }

    if ($PSBoundParameters.ContainsKey('AlarmObjectType')) {
        $catalog = Get-DMAlarmType -WebSession $session
        $match = @($catalog | Where-Object { $_.Name -eq $AlarmObjectType })
        if ($match.Count -eq 0) {
            $validNames = ($catalog.Name | Sort-Object) -join ', '
            throw "Unknown alarm object type '$AlarmObjectType'. Valid names: $validNames"
        }
        $clauses.Add("alarmObjType::$($match[0].ObjectType)")
    }

    $hasStartTime = $PSBoundParameters.ContainsKey('StartTime')
    $hasEndTime = $PSBoundParameters.ContainsKey('EndTime')

    if ($Last) {
        $EndTime = Get-Date
        $StartTime = $EndTime - $Last
        $hasStartTime = $true
        $hasEndTime = $true
    }

    if ($hasStartTime -or $hasEndTime) {
        if (-not $hasEndTime) {
            $EndTime = Get-Date
        }
        if (-not $hasStartTime) {
            $StartTime = [System.DateTimeOffset]::FromUnixTimeSeconds(0).DateTime
        }
        $startEpoch = [System.DateTimeOffset]::new($StartTime.ToUniversalTime()).ToUnixTimeSeconds()
        $endEpoch = [System.DateTimeOffset]::new($EndTime.ToUniversalTime()).ToUnixTimeSeconds()
        $clauses.Add("startTime:[$startEpoch,$endEpoch]")
    }

    if ($PSBoundParameters.ContainsKey('Sequence')) {
        $clauses.Add("sequence::$Sequence")
    }

    if ($PSBoundParameters.ContainsKey('StartSequence')) {
        $clauses.Add("startSeq::$StartSequence")
    }

    if ($PSBoundParameters.ContainsKey('EndSequence')) {
        $clauses.Add("endSeq::$EndSequence")
    }

    $resource = 'alarm/historyalarm?sortby=startTime,d'
    if ($clauses.Count -gt 0) {
        $filter = $clauses -join ' and '
        $resource += "&filter=$filter"
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource

    $alarms = New-Object System.Collections.ArrayList

    foreach ($talarm in $response) {
        $alarm = [OceanStorAlarm]::new($talarm, $session)
        [void]$alarms.Add($alarm)
    }

    $alarms | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $alarms
}
