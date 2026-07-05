function Get-DMLLDPWorkingMode {
    <#
    .SYNOPSIS
        Gets the OceanStor LLDP working mode.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $response = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource 'LLDP_WORKING_MODE' |
        Select-DMResponseData

    $mode = [int]$response.lldpWorkingMode
    $modeName = switch ($mode) {
        0 { 'Disabled' }
        1 { 'Transmit' }
        2 { 'Receive' }
        3 { 'TransmitReceive' }
        default { $response.lldpWorkingMode }
    }

    [pscustomobject]@{
        WorkingMode     = $mode
        WorkingModeName = $modeName
        lldpWorkingMode = $response.lldpWorkingMode
    }
}
