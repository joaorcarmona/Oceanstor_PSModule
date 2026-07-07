function Set-DMLLDPWorkingMode {
    <#
    .SYNOPSIS
        Changes the OceanStor LLDP working mode.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('0', '1', '2', '3', 'Disabled', 'Transmit', 'Receive', 'TransmitReceive')]
        [string]$WorkingMode
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $modeValue = switch ($WorkingMode) {
        'Disabled' { '0' }
        'Transmit' { '1' }
        'Receive' { '2' }
        'TransmitReceive' { '3' }
        default { $WorkingMode }
    }

    if ($PSCmdlet.ShouldProcess($modeValue, 'Change LLDP working mode')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'LLDP_WORKING_MODE' -BodyData @{
            lldpWorkingMode = $modeValue
        }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
