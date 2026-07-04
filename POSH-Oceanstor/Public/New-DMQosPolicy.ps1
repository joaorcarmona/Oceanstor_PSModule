function New-DMQosPolicy {
    <#
    .SYNOPSIS
        Creates an OceanStor SmartQoS policy.

    .DESCRIPTION
        Creates a SmartQoS policy via the ioclass resource. At least one of MaxBandwidth,
        MaxIOPS, MinBandwidth, MinIOPS, Latency must be supplied, matching the API's own
        requirement. LunName/LunId and FileSystemName/FileSystemId are mutually exclusive,
        since LUNs/LUN snapshots and file systems cannot coexist in one SmartQoS policy.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER Name
        SmartQoS policy name, 1-31 characters (letters, digits, underscores, hyphens, periods).

    .PARAMETER Description
        Optional description, 0-255 characters.

    .PARAMETER IOType
        I/O property the policy applies to: ReadWrite (default) or Split (read I/O or write I/O counted separately).

    .PARAMETER MaxBandwidth
        Maximum bandwidth in MB/s (1-999,999,999).

    .PARAMETER MaxIOPS
        Maximum IOPS (100-999,999,999).

    .PARAMETER MinBandwidth
        Minimum bandwidth in MB/s (1-999,999,999).

    .PARAMETER MinIOPS
        Minimum IOPS (100-999,999,999).

    .PARAMETER Latency
        I/O latency target in microseconds: 500 or 1500.

    .PARAMETER BurstBandwidth
        Maximum burst bandwidth in MB/s. Requires BurstTime.

    .PARAMETER BurstIOPS
        Maximum burst IOPS. Requires BurstTime.

    .PARAMETER BurstTime
        Burst time in seconds (1-999,999,999). Mandatory when BurstBandwidth or BurstIOPS is specified.

    .PARAMETER Priority
        Normal (default) or High. When High, the policy's performance objective is ensured first.

    .PARAMETER SchedulePolicy
        Once (default), Daily, or Weekly.

    .PARAMETER ScheduleStartTime
        Date (UTC) the policy settings take effect. Only year/month/day are effective.

    .PARAMETER StartTime
        Time of day the policy settings take effect, in hh:mm format.

    .PARAMETER Duration
        Validity period of the policy settings, in seconds, less than 24 hours (86400).

    .PARAMETER CycleSet
        Cycle days (0-6, Sunday-Saturday) the policy applies on. Mandatory when SchedulePolicy is Weekly.

    .PARAMETER LunName
        LUN name(s) to attach to the policy. Mutually exclusive with FileSystemName/FileSystemId.

    .PARAMETER LunId
        LUN ID(s) to attach to the policy. Mutually exclusive with FileSystemName/FileSystemId.

    .PARAMETER FileSystemName
        File system name(s) to attach to the policy. Mutually exclusive with LunName/LunId.

    .PARAMETER FileSystemId
        File system ID(s) to attach to the policy. Mutually exclusive with LunName/LunId.

    .PARAMETER VstoreId
        Optional vStore ID. A value of 4294967295 lets the policy take effect on any vStore in the system.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorQosPolicy

    .EXAMPLE
        PS> New-DMQosPolicy -Name 'qos01' -MaxIOPS 5000 -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600

    .EXAMPLE
        PS> New-DMQosPolicy -Name 'qos02' -MaxBandwidth 500 -LunName 'lun01', 'lun02' -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'NoAssociation')]
    [OutputType([OceanstorQosPolicy])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateLength(1, 31)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [AllowEmptyString()]
        [ValidateLength(0, 255)]
        [string]$Description,

        [ValidateSet('ReadWrite', 'Split')]
        [string]$IOType = 'ReadWrite',

        [ValidateRange(1, 999999999)]
        [uint32]$MaxBandwidth,

        [ValidateRange(100, 999999999)]
        [uint32]$MaxIOPS,

        [ValidateRange(1, 999999999)]
        [uint32]$MinBandwidth,

        [ValidateRange(100, 999999999)]
        [uint32]$MinIOPS,

        [ValidateSet(500, 1500)]
        [uint32]$Latency,

        [ValidateRange(1, 999999999)]
        [uint32]$BurstBandwidth,

        [ValidateRange(100, 999999999)]
        [uint32]$BurstIOPS,

        [ValidateRange(1, 999999999)]
        [uint32]$BurstTime,

        [ValidateSet('Normal', 'High')]
        [string]$Priority = 'Normal',

        [ValidateSet('Once', 'Daily', 'Weekly')]
        [string]$SchedulePolicy = 'Once',

        [Parameter(Mandatory = $true)]
        [datetime]$ScheduleStartTime,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')]
        [string]$StartTime,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 86399)]
        [uint32]$Duration,

        [ValidateScript({
                foreach ($day in $_) {
                    if ($day -lt 0 -or $day -gt 6) { throw 'CycleSet values must be between 0 (Sunday) and 6 (Saturday).' }
                }
                return $true
            })]
        [int[]]$CycleSet,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string[]]$LunName,

        [string[]]$LunId,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string[]]$FileSystemName,

        [string[]]$FileSystemId,

        [string]$VstoreId
    )

    begin {
        $hasLimit = $PSBoundParameters.ContainsKey('MaxBandwidth') -or
            $PSBoundParameters.ContainsKey('MaxIOPS') -or
            $PSBoundParameters.ContainsKey('MinBandwidth') -or
            $PSBoundParameters.ContainsKey('MinIOPS') -or
            $PSBoundParameters.ContainsKey('Latency')
        if (-not $hasLimit) {
            throw 'Specify at least one of MaxBandwidth, MaxIOPS, MinBandwidth, MinIOPS, Latency.'
        }
        if (($PSBoundParameters.ContainsKey('BurstBandwidth') -or $PSBoundParameters.ContainsKey('BurstIOPS')) -and -not $PSBoundParameters.ContainsKey('BurstTime')) {
            throw 'BurstTime is mandatory when BurstBandwidth or BurstIOPS is specified.'
        }
        if ($SchedulePolicy -eq 'Weekly' -and -not $PSBoundParameters.ContainsKey('CycleSet')) {
            throw 'CycleSet is mandatory when SchedulePolicy is Weekly.'
        }
        $lunParamsSpecified = $PSBoundParameters.ContainsKey('LunName') -or $PSBoundParameters.ContainsKey('LunId')
        $fsParamsSpecified = $PSBoundParameters.ContainsKey('FileSystemName') -or $PSBoundParameters.ContainsKey('FileSystemId')
        if ($PSBoundParameters.ContainsKey('LunName') -and $PSBoundParameters.ContainsKey('LunId')) {
            throw 'LunName and LunId are mutually exclusive.'
        }
        if ($PSBoundParameters.ContainsKey('FileSystemName') -and $PSBoundParameters.ContainsKey('FileSystemId')) {
            throw 'FileSystemName and FileSystemId are mutually exclusive.'
        }
        if ($lunParamsSpecified -and $fsParamsSpecified) {
            throw 'LunName/LunId and FileSystemName/FileSystemId are mutually exclusive.'
        }
    }

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $body = @{
                NAME              = $Name
                IOTYPE            = switch ($IOType) { 'ReadWrite' { 2 }; 'Split' { 3 } }
                PRIORITY          = switch ($Priority) { 'Normal' { 0 }; 'High' { 1 } }
                SCHEDULEPOLICY    = switch ($SchedulePolicy) { 'Once' { 0 }; 'Daily' { 1 }; 'Weekly' { 2 } }
                SCHEDULESTARTTIME = [System.DateTimeOffset]::new($ScheduleStartTime.ToUniversalTime()).ToUnixTimeSeconds()
                STARTTIME         = $StartTime
                DURATION          = $Duration
            }

            if ($Description) { $body.DESCRIPTION = $Description }
            if ($PSBoundParameters.ContainsKey('MaxBandwidth')) { $body.MAXBANDWIDTH = $MaxBandwidth }
            if ($PSBoundParameters.ContainsKey('MaxIOPS')) { $body.MAXIOPS = $MaxIOPS }
            if ($PSBoundParameters.ContainsKey('MinBandwidth')) { $body.MINBANDWIDTH = $MinBandwidth }
            if ($PSBoundParameters.ContainsKey('MinIOPS')) { $body.MINIOPS = $MinIOPS }
            if ($PSBoundParameters.ContainsKey('Latency')) { $body.LATENCY = $Latency }
            if ($PSBoundParameters.ContainsKey('BurstBandwidth')) { $body.BURSTBANDWIDTH = $BurstBandwidth }
            if ($PSBoundParameters.ContainsKey('BurstIOPS')) { $body.BURSTIOPS = $BurstIOPS }
            if ($PSBoundParameters.ContainsKey('BurstTime')) { $body.BURSTTIME = $BurstTime }
            if ($PSBoundParameters.ContainsKey('CycleSet')) { $body.CYCLESET = @($CycleSet) }
            if ($VstoreId) { $body.vstoreId = $VstoreId }

            if ($PSBoundParameters.ContainsKey('LunName')) {
                $lunIds = foreach ($name in $LunName) {
                    $lun = @(Get-DMlun -WebSession $session -Name $name | Where-Object Name -EQ $name)[0]
                    if ($null -eq $lun) { throw "Could not resolve LunName '$name'." }
                    $lun.Id
                }
                $body.LUNLIST = @($lunIds)
            }
            elseif ($PSBoundParameters.ContainsKey('LunId')) {
                $body.LUNLIST = @($LunId)
            }
            elseif ($PSBoundParameters.ContainsKey('FileSystemName')) {
                $fsIds = foreach ($name in $FileSystemName) {
                    $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -CEQ $name)[0]
                    if ($null -eq $fileSystem) { throw "Could not resolve FileSystemName '$name'." }
                    $fileSystem.Id
                }
                $body.FSLIST = @($fsIds)
            }
            elseif ($PSBoundParameters.ContainsKey('FileSystemId')) {
                $body.FSLIST = @($FileSystemId)
            }

            if (-not $PSCmdlet.ShouldProcess($Name, 'Create SmartQoS policy')) {
                return
            }

            $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'ioclass' -BodyData $body
            $response = $response | Assert-DMApiSuccess
            return [OceanstorQosPolicy]::new($response.data, $session)
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
