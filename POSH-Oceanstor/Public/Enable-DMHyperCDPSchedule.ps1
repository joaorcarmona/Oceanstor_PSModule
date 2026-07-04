function Enable-DMHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ById')]
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

            $query = @('SCHEDULETYPE=1')
            if ($VstoreId) { $query += "vstoreId=$([uri]::EscapeDataString($VstoreId))" }
            $body = @{
                ID = $schedule.Id
                ENABLESCHEDULE = $true
            }

            if ($PSCmdlet.ShouldProcess($schedule.Name, 'Enable HyperCDP schedule')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "snapshot_schedule/enable_snapshot_schedule?$($query -join '&')" -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
