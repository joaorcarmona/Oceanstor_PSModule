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
                # The modify interface (PUT vlan/{id}, OceanStor Dorado 6.1.6 REST
                # reference 4.6.9.3.8) marks both ID and MTU as Mandatory body fields.
                # Sending MTU alone (ID only in the URL path) makes the array reject the
                # payload with OceanStor API error 50331651 ("The entered parameter is
                # incorrect"), so echo the ID in the body as well as the path.
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "vlan/$([uri]::EscapeDataString($Id))" -BodyData @{ ID = $Id; MTU = $Mtu }
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
