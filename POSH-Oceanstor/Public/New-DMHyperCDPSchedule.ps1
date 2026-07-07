function New-DMHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    # String form: class type literals in attributes do not resolve inside module scope.
    [OutputType('OceanstorHyperCDPSchedule')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Description,

        [ValidateSet('Block', 'File')]
        [string]$ObjectType = 'Block',

        [ValidateRange(3, 86400)]
        [int]$FrequencyValueSeconds,

        [ValidateRange(1, 60000)]
        [int]$FrequencySnapshotCount,

        [int[]]$DayHours,

        [ValidateRange(0, 59)]
        [int]$DayMinute,

        [ValidateRange(1, 512)]
        [int]$DailySnapshotCount,

        [int[]]$WeeklyDays,

        [string]$StartTimeOfWeek,

        [ValidateRange(1, 256)]
        [int]$WeeklySnapshotCount,

        [string[]]$MonthDays,

        [string]$StartTimeOfMonth,

        [ValidateRange(1, 256)]
        [int]$MonthlySnapshotCount,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

    $payloadParameters = @{
        Name = $Name
        ObjectType = $ObjectType
    }
    foreach ($key in @(
            'Description', 'FrequencyValueSeconds', 'FrequencySnapshotCount',
            'DayHours', 'DayMinute', 'DailySnapshotCount',
            'WeeklyDays', 'StartTimeOfWeek', 'WeeklySnapshotCount',
            'MonthDays', 'StartTimeOfMonth', 'MonthlySnapshotCount', 'VstoreId'
        )) {
        if ($PSBoundParameters.ContainsKey($key)) {
            $payloadParameters[$key] = (Get-Variable -Name $key -ValueOnly)
        }
    }
    $body = ConvertTo-DMHyperCDPSchedulePayload @payloadParameters

    if ($PSCmdlet.ShouldProcess($Name, 'Create HyperCDP schedule')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot_schedule' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0 -and $response.data) {
            return [OceanstorHyperCDPSchedule]::new($response.data, $session)
        }
        return $response.error
    }
}
