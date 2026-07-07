function New-DMvLan {
    <#
    .SYNOPSIS
        Creates an OceanStor VLAN port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateRange(1, 4094)]
        [int]$Tag,

        [Parameter(Mandatory = $true)]
        [ValidateSet(1, 7)]
        [int]$PortType,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PortId
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{
        TAG      = $Tag
        PORTTYPE = $PortType
        PORTID   = $PortId
    }

    if ($PSCmdlet.ShouldProcess("$PortId.$Tag", 'Create VLAN port')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'vlan' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0 -and $response.data) {
            return [OceanStorvLan]::new($response.data, $session)
        }

        return $response.error
    }
}
