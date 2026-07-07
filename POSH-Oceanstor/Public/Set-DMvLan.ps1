function Set-DMvLan {
    <#
    .SYNOPSIS
        Modifies an OceanStor VLAN port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1280, 9000)]
        [int]$Mtu
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            if ($PSCmdlet.ShouldProcess($Id, 'Modify VLAN port')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "vlan/$([uri]::EscapeDataString($Id))" -BodyData @{ MTU = $Mtu }
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
