function Get-DMAlarmType {
    <#
    .SYNOPSIS
        Gets the Huawei OceanStor alarm object-type catalog (read-only).

    .DESCRIPTION
        Batch-queries the array's alarm object types via the documented read-only
        endpoint (GET ALARM_DEFINITION_OBJ, "Interface for Batch Querying Alarm
        Types", OceanStor Dorado 6.1.6 REST Interface Reference section 4.2.2.4.1).

        Each alarm object type has a human-readable name (for example port, disk,
        LUN) and a numeric object-type value used by the alarm/event query filter
        (alarmObjType). This cmdlet exposes that catalog so the numeric values can
        be discovered, and it is reused by Get-DMAlarmHistory to resolve an
        -AlarmObjectType name into its numeric filter value.

    .PARAMETER WebSession
        Optional session to use on the REST call. If not defined, the module's
        cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Name
        Optional. Return only the alarm object type(s) whose Name matches this
        value (case-insensitive, exact match). When omitted, the full catalog is
        returned.

    .INPUTS
        System.Management.Automation.PSCustomObject

        You can pipe an OceanStor session object to WebSession.

    .OUTPUTS
        System.Management.Automation.PSCustomObject

        One object per alarm object type, with Name, ObjectType, and Id.

    .EXAMPLE
        PS C:\> Get-DMAlarmType

        Lists every alarm object type known to the array.

    .EXAMPLE
        PS C:\> Get-DMAlarmType -Name disk

        Returns the disk alarm object type, exposing the ObjectType value to use
        with Get-DMAlarmHistory -AlarmObjectType.

    .NOTES
        Filename: Get-DMAlarmType.ps1
        Read-only.

    .LINK
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0, Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    $defaultDisplaySet = 'Name', 'ObjectType'

    $displayPropertySet = New-Object System.Management.Automation.PSPropertySet(
        'DefaultDisplayPropertySet',
        [string[]]$defaultDisplaySet
    )

    $standardMembers = [System.Management.Automation.PSMemberInfo[]]@($displayPropertySet)

    # language=1 selects the English names (2 is Chinese), per the reference doc.
    # ALARM_DEFINITION_OBJ documents only the language parameter and does not
    # support range paging (it ignores range and returns the full fixed catalog
    # in a single response), so this issues one direct request rather than using
    # Invoke-DMPagedRequest, whose range-repeat guard would otherwise trip.
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'ALARM_DEFINITION_OBJ?language=1'
    $data = @($response | Select-DMResponseData)

    $alarmTypes = New-Object System.Collections.ArrayList

    foreach ($item in $data) {
        $alarmType = [pscustomobject]@{
            Name       = $item.CMO_ALARM_OBJ_NAME
            ObjectType = $item.CMO_ALARM_OBJ_TYPE
            Id         = $item.ID
        }

        $alarmType | Add-Member MemberSet PSStandardMembers $standardMembers -Force
        [void]$alarmTypes.Add($alarmType)
    }

    if ($PSBoundParameters.ContainsKey('Name')) {
        $alarmTypes = @($alarmTypes | Where-Object { $_.Name -eq $Name })
    }

    return $alarmTypes
}
