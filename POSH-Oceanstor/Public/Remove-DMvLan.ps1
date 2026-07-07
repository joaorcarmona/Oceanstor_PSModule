function Remove-DMvLan {
    <#
    .SYNOPSIS
        Removes an OceanStor VLAN port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            if ($PSCmdlet.ShouldProcess($Id, 'Remove VLAN port')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "vlan/$([uri]::EscapeDataString($Id))"
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}

Set-Alias -Name Delete-DMvLan -Value Remove-DMvLan
