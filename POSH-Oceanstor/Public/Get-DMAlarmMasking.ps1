function Get-DMAlarmMasking {
    <#
    .SYNOPSIS
        Queries Huawei OceanStor alarm maskings (read-only).

    .DESCRIPTION
        Queries the array's alarm masking configuration via the OceanStor "Interface
        for Querying Alarm Maskings" (GET ALARM_DEFINITION, OceanStor Dorado 6.1.6
        REST Interface Reference section 4.2.2.4.3).

        Alarm masking controls whether a given alarm definition is suppressed
        (masked) on the array. Each record exposes the alarm definition (alarm ID,
        name, severity, object type), whether masking is currently enabled, and
        whether an uncleared instance of that alarm currently exists.

        The three documented server-side filter fields are exposed as friendly
        parameters and AND-combined:

            Level             CMO_ALARM_LEVEL  (Info=2, Warning=3, Major=5, Critical=6)
            AlarmObjectType   CMO_ALARM_OBJ_TYPE (resolved from a name via Get-DMAlarmType)
            Masked            enableClose      ($true => true, $false => false)

        All filters are optional; when none are supplied the full masking catalog is
        returned. Results are fully paged.

        Use Set-DMAlarmMasking to enable or disable masking for a specific alarm ID.

    .PARAMETER WebSession
        Optional session to use on the REST call. If not defined, the module's cached
        $script:CurrentOceanstorSession session is used.

    .PARAMETER Level
        Optional alarm severity filter. Valid values: Info, Warning, Major, Critical.

    .PARAMETER AlarmObjectType
        Optional alarm object-type filter, given as a name from the array's alarm
        type catalog (see Get-DMAlarmType), for example disk, LUN, or port. The name
        is resolved to its numeric object-type value before querying. An unknown name
        is rejected with the list of valid names.

    .PARAMETER Masked
        Optional masking-state filter. Pass $true to return only masked alarms, or
        $false to return only unmasked alarms. When omitted, both are returned.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        OceanStorAlarmMasking

        One object per alarm definition, exposing Alarm Id, Name, Level, Alarm Object
        Type (friendly name resolved from the Get-DMAlarmType catalog), Alarm Object
        Type Id (the underlying numeric value), Masked, and Uncleared Alarm Exists.

    .EXAMPLE
        PS C:\> Get-DMAlarmMasking

        Lists every alarm masking record known to the array.

    .EXAMPLE
        PS C:\> Get-DMAlarmMasking -Masked $true

        Returns only the alarms that are currently masked.

    .EXAMPLE
        PS C:\> Get-DMAlarmMasking -Level Critical -AlarmObjectType disk

        Returns disk-related critical-severity alarm masking records.

    .NOTES
        Filename: Get-DMAlarmMasking.ps1
        Read-only.

    .LINK
    #>
    [CmdletBinding()]
    [OutputType('OceanStorAlarmMasking')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Major', 'Critical')]
        [string]$Level,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$AlarmObjectType,

        [Parameter(Mandatory = $false)]
        [bool]$Masked
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = 'Name', 'Level', 'Alarm Object Type', 'Masked', 'Uncleared Alarm Exists'

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    # Fetch the alarm object-type catalog once. It is reused both to resolve an
    # -AlarmObjectType name into its numeric filter value and to translate each
    # result's numeric object type back into a friendly name (Alarm Object Type).
    $catalog = @(Get-DMAlarmType -WebSession $session)
    $objectTypeMap = @{}
    foreach ($entry in $catalog) {
        $objectTypeMap[[string]$entry.ObjectType] = $entry.Name
    }

    # The ALARM_DEFINITION interface documents three filter fields
    # (CMO_ALARM_LEVEL, CMO_ALARM_OBJ_TYPE, enableClose). Each supplied friendly
    # value is mapped to the documented field/value and the clauses are AND-joined,
    # using the same field::value filter syntax as Get-DMAlarmHistory.
    $clauses = New-Object System.Collections.Generic.List[string]

    if ($PSBoundParameters.ContainsKey('Level')) {
        $levelValue = switch ($Level) {
            'Info' { 2 }
            'Warning' { 3 }
            'Major' { 5 }
            'Critical' { 6 }
        }
        $clauses.Add("CMO_ALARM_LEVEL::$levelValue")
    }

    if ($PSBoundParameters.ContainsKey('AlarmObjectType')) {
        $match = @($catalog | Where-Object { $_.Name -eq $AlarmObjectType })
        if ($match.Count -eq 0) {
            $validNames = ($catalog.Name | Sort-Object) -join ', '
            throw "Unknown alarm object type '$AlarmObjectType'. Valid names: $validNames"
        }
        $clauses.Add("CMO_ALARM_OBJ_TYPE::$($match[0].ObjectType)")
    }

    if ($PSBoundParameters.ContainsKey('Masked')) {
        $enableValue = if ($Masked) { 'true' } else { 'false' }
        $clauses.Add("enableClose::$enableValue")
    }

    # language=1 selects the English alarm names (2 is Chinese), per the reference.
    $resource = 'ALARM_DEFINITION?language=1'
    if ($clauses.Count -gt 0) {
        $filter = $clauses -join ' and '
        $resource += "&filter=$filter"
    }

    $response = Invoke-DMPagedRequest -WebSession $session -Resource $resource

    $maskings = New-Object System.Collections.ArrayList

    foreach ($item in $response) {
        $masking = [OceanStorAlarmMasking]::new($item, $session, $objectTypeMap)
        [void]$maskings.Add($masking)
    }

    $maskings | ForEach-Object {
        $_ | Add-Member MemberSet PSStandardMembers $standardMembers -Force
    }

    return $maskings
}
