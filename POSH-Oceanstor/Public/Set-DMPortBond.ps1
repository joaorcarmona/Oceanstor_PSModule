function Set-DMPortBond {
    <#
    .SYNOPSIS
        Modifies an OceanStor bond port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true)]
        [ValidateLength(1, 31)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [ValidateRange(1280, 9000)]
        [int]$Mtu,

        [string]$IPv4Address,
        [string]$IPv4Mask,
        [string]$IPv6Address,
        [string]$IPv6Mask,

        [ValidateSet(1, 2)]
        [int]$UsedType,

        [ValidateSet(0, 1)]
        [int]$MsgReturnType
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                Id            = 'ID'
                Name          = 'NAME'
                Mtu           = 'MTU'
                IPv4Address   = 'IPV4ADDR'
                IPv4Mask      = 'IPV4MASK'
                IPv6Address   = 'IPV6ADDR'
                IPv6Mask      = 'IPV6MASK'
                UsedType      = 'USEDTYPE'
                MsgReturnType = 'MSGRETURNTYPE'
            }

            $resource = if ($Id) { "bond_port/$([uri]::EscapeDataString($Id))" } else { 'bond_port' }
            $target = if ($Id) { $Id } else { $Name }
            if ($PSCmdlet.ShouldProcess($target, 'Modify bond port')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $resource -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
