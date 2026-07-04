function Add-DMLunToHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByLunName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ParameterSetName = 'ByLunObject', ValueFromPipeline = $true, Mandatory = $true)]
        [psobject]$InputObject,

        [Parameter(ParameterSetName = 'ByLunName', Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [string]$LunName,

        [Parameter(ParameterSetName = 'ByLunId', Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Id')]
        [ValidateNotNullOrEmpty()]
        [string]$LunId,

        [Parameter()]
        [Alias('HyperCDPScheduleId')]
        [string]$ScheduleId,

        [Parameter()]
        [Alias('HyperCDPScheduleName')]
        [string]$ScheduleName,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $lun = switch ($PSCmdlet.ParameterSetName) {
                'ByLunObject' { Resolve-DMHyperCDPLun -WebSession $session -InputObject $InputObject }
                'ByLunId' { Resolve-DMHyperCDPLun -WebSession $session -LunId $LunId }
                default { Resolve-DMHyperCDPLun -WebSession $session -LunName $LunName }
            }
            if ($ScheduleId -and $ScheduleName) {
                throw 'ScheduleId and ScheduleName cannot be used together.'
            }
            if (-not $ScheduleId -and -not $ScheduleName) {
                throw 'ScheduleId or ScheduleName is required.'
            }
            $schedule = if ($ScheduleId) {
                Resolve-DMHyperCDPSchedule -WebSession $session -Id $ScheduleId
            }
            else {
                Resolve-DMHyperCDPSchedule -WebSession $session -Name $ScheduleName
            }

            $body = @{
                ID = $schedule.Id
                ASSOCIATEOBJTYPE = 11
                ASSOCIATEOBJID = $lun.Id
                SCHEDULETYPE = 1
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$($lun.Name) -> $($schedule.Name)", 'Add LUN to HyperCDP schedule')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snapshot_schedule/create_associate' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
