function Remove-DMLunFromHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByLunName')]
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

            $query = @(
                "ID=$($schedule.Id)",
                'ASSOCIATEOBJTYPE=11',
                "ASSOCIATEOBJID=$($lun.Id)",
                'SCHEDULETYPE=1'
            )
            if ($VstoreId) {
                $query += "vstoreId=$([uri]::EscapeDataString($VstoreId))"
            }

            if ($PSCmdlet.ShouldProcess("$($lun.Name) <- $($schedule.Name)", 'Remove LUN from HyperCDP schedule')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "snapshot_schedule/remove_associate?$($query -join '&')"
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
