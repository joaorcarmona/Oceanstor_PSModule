function Set-DMTimeZone {
    <#
    .SYNOPSIS
        Sets the OceanStor equipment time zone.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$TimeZoneName
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess($TimeZoneName, 'Set equipment time zone')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'system_timezone' -BodyData @{
            CMO_SYS_TIME_ZONE_NAME = $TimeZoneName
        }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
