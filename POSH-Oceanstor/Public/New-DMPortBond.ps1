function New-DMPortBond {
    <#
    .SYNOPSIS
        Creates an OceanStor bond port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Position = 0)]
        [ValidateLength(1, 31)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$PortIdList,

        [ValidateSet(1, 2, 4)]
        [int]$BondPortType,

        [ValidateSet(0, 1)]
        [int]$MsgReturnType
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
        Name          = 'NAME'
        PortIdList    = 'PORTIDLIST'
        BondPortType  = 'bondPortType'
        MsgReturnType = 'MSGRETURNTYPE'
    }

    $target = if ($Name) { $Name } else { $PortIdList -join ', ' }
    if ($PSCmdlet.ShouldProcess($target, 'Create bond port')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'bond_port' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0 -and $response.data) {
            return [OceanStorPortBond]::new($response.data, $session)
        }

        return $response.error
    }
}
