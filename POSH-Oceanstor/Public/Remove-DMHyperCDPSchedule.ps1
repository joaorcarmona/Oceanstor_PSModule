function Remove-DMHyperCDPSchedule {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ById')]
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

        [switch]$ForceDelete,

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
            if ($ForceDelete) { $query += 'forceFlag=1' }
            $resource = "snapshot_schedule/$($schedule.Id)?$($query -join '&')"

            if ($PSCmdlet.ShouldProcess($schedule.Name, 'Remove HyperCDP schedule')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
