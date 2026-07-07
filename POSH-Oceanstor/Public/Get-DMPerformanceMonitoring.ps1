function Get-DMPerformanceMonitoring {
    <#
    .SYNOPSIS
        Retrieves the current OceanStor performance-monitoring configuration.

    .DESCRIPTION
        Merges the performance_statistic_switch and performance_statistic_strategy GET responses
        into a single OceanStor.PerformanceMonitoringStatus object.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Get-DMPerformanceMonitoring

    .NOTES
        Filename: Get-DMPerformanceMonitoring.ps1
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Mandatory = $false)]
        [pscustomobject]$WebSession
    )

    process {
        $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

        $switchData = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'performance_statistic_switch' | Select-DMResponseData
        $strategyData = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'performance_statistic_strategy' | Select-DMResponseData

        $switchObject = @($switchData)[0]
        $strategyObject = @($strategyData)[0]

        return New-DMPerformanceMonitoringStatus -Switch $switchObject -Strategy $strategyObject -Session $session
    }
}
