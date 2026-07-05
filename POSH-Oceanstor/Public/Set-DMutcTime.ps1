function Set-DMutcTime {
    <#
    .SYNOPSIS
        Sets the OceanStor equipment UTC time.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(946656000, 3000000000)]
        [uint64]$UtcTime
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess($UtcTime, 'Set equipment UTC time')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'system_utc_time' -BodyData @{
            CMO_SYS_UTC_TIME = $UtcTime
        }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
