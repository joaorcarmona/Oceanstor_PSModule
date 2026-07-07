function Disable-DMPerformanceMonitoring {
    <#
    .SYNOPSIS
        Disables OceanStor realtime performance statistics collection.

    .DESCRIPTION
        Sets CMO_PERFORMANCE_SWITCH to 0 via the performance_statistic_switch resource.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Disable-DMPerformanceMonitoring

    .NOTES
        Filename: Disable-DMPerformanceMonitoring.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            $body = @{
                CMO_PERFORMANCE_SWITCH = 0
            }

            if ($PSCmdlet.ShouldProcess('OceanStor', 'Disable performance monitoring')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'performance_statistic_switch' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
