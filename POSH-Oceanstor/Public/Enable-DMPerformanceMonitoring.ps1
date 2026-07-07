function Enable-DMPerformanceMonitoring {
    <#
    .SYNOPSIS
        Enables OceanStor realtime performance statistics collection.

    .DESCRIPTION
        Sets CMO_PERFORMANCE_SWITCH to 1 via the performance_statistic_switch resource.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Enable-DMPerformanceMonitoring

    .NOTES
        Filename: Enable-DMPerformanceMonitoring.ps1
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
                CMO_PERFORMANCE_SWITCH = 1
            }

            if ($PSCmdlet.ShouldProcess('OceanStor', 'Enable performance monitoring')) {
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
