function Set-DMHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'ById')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByObject', ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$InputObject,

        [Parameter(ParameterSetName = 'ById', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string]$ScheduleId,

        [Parameter(ParameterSetName = 'ByName', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScheduleName,

        [string]$Name,

        [string]$Description,

        [int]$FrequencyValueSeconds,

        [int]$FrequencySnapshotCount,

        [int[]]$DayHours,

        [int]$DayMinute,

        [int]$DailySnapshotCount,

        [int[]]$WeeklyDays,

        [string]$StartTimeOfWeek,

        [int]$WeeklySnapshotCount,

        [string[]]$MonthDays,

        [string]$StartTimeOfMonth,

        [int]$MonthlySnapshotCount,

        [switch]$RetainPreviousSnapshot,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $schedule = switch ($PSCmdlet.ParameterSetName) {
                'ByObject' { Resolve-DMHyperCDPSchedule -WebSession $session -InputObject $InputObject }
                'ByName' { Resolve-DMHyperCDPSchedule -WebSession $session -Name $ScheduleName }
                default { Resolve-DMHyperCDPSchedule -WebSession $session -Id $ScheduleId }
            }

            $payloadKeys = @(
                'Name', 'Description', 'FrequencyValueSeconds', 'FrequencySnapshotCount',
                'DayHours', 'DayMinute', 'DailySnapshotCount',
                'WeeklyDays', 'StartTimeOfWeek', 'WeeklySnapshotCount',
                'MonthDays', 'StartTimeOfMonth', 'MonthlySnapshotCount', 'VstoreId'
            )
            $payloadParameters = @{ ForUpdate = $true }
            foreach ($key in $payloadKeys) {
                if ($PSBoundParameters.ContainsKey($key)) {
                    $payloadParameters[$key] = (Get-Variable -Name $key -ValueOnly)
                }
            }
            $hasPayloadField = @($payloadKeys | Where-Object { $PSBoundParameters.ContainsKey($_) }).Count -gt 0
            $body = if ($hasPayloadField) {
                ConvertTo-DMHyperCDPSchedulePayload @payloadParameters
            }
            elseif ($RetainPreviousSnapshot) {
                @{ SCHEDULETYPE = 1 }
            }
            else {
                throw 'At least one schedule property or policy must be supplied.'
            }
            if ($RetainPreviousSnapshot) {
                $body.isRetainPreviousSnapshot = $true
            }

            if ($PSCmdlet.ShouldProcess($schedule.Name, 'Modify HyperCDP schedule')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "snapshot_schedule/$($schedule.Id)" -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
