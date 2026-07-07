function Set-DMLif {
    <#
    .SYNOPSIS
        Modifies an OceanStor logical interface port.

    .DESCRIPTION
        The target can be addressed by -Name, by -Id, or both. The REST modify
        interface documents NAME as a mandatory body field, so when only -Id is
        supplied the current name is resolved first through the documented
        lif/${id} query and sent alongside the ID.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [string]$Id,

        [Parameter(Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('LIF Name')]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [string]$IPv4Address,
        [string]$IPv4Mask,
        [string]$IPv4Gateway,
        [string]$IPv6Address,
        [string]$IPv6Mask,
        [string]$IPv6Gateway,
        [ValidateSet(1, 7, 8, 25, 26)]
        [int]$HomePortType,
        [string]$HomePortId,
        [string]$HomePortName,
        [string]$CurrentPortId,
        [bool]$OperationalStatus,
        [ValidateSet(0, 1)]
        [int]$AddressFamily,
        [bool]$IsPrivate,
        [string]$FailoverGroupId,
        [bool]$CanFailover,
        [ValidateSet(1, 2)]
        [int]$FailbackMode,
        [ValidateSet(0, 1, 2)]
        [int]$DdnsStatus,
        [string]$DnsZoneName,
        [ValidateSet(0, 1)]
        [int]$ListenDnsQueryEnabled,
        [string]$HomeControllerId,
        [string]$HomeSiteWwn,
        [ValidateSet(1)]
        [int]$RemoveFromDnsZone
    )

    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Id') -and -not $PSBoundParameters.ContainsKey('Name')) {
                throw 'Specify -Id or -Name to identify the logical interface to modify.'
            }
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                Id                    = 'ID'
                Name                  = 'NAME'
                IPv4Address           = 'IPV4ADDR'
                IPv4Mask              = 'IPV4MASK'
                IPv4Gateway           = 'IPV4GATEWAY'
                IPv6Address           = 'IPV6ADDR'
                IPv6Mask              = 'IPV6MASK'
                IPv6Gateway           = 'IPV6GATEWAY'
                HomePortType          = 'HOMEPORTTYPE'
                HomePortId            = 'HOMEPORTID'
                HomePortName          = 'HOMEPORTNAME'
                CurrentPortId         = 'CURRENTPORTID'
                OperationalStatus     = 'OPERATIONALSTATUS'
                AddressFamily         = 'ADDRESSFAMILY'
                IsPrivate             = 'ISPRIVATE'
                FailoverGroupId       = 'FAILOVERGROUPID'
                CanFailover           = 'CANFAILOVER'
                FailbackMode          = 'FAILBACKMODE'
                DdnsStatus            = 'ddnsStatus'
                DnsZoneName           = 'dnsZoneName'
                ListenDnsQueryEnabled = 'listenDnsQueryEnabled'
                HomeControllerId      = 'HOMECONTROLLERID'
                HomeSiteWwn           = 'HOMESITEWWN'
                RemoveFromDnsZone     = 'removeFromDnsZone'
            }

            $target = if ($Name) { $Name } else { $Id }
            if ($PSCmdlet.ShouldProcess($target, 'Modify logical interface')) {
                if ($Id -and -not $Name) {
                    # The documented lif PUT requires NAME in the body; resolve the
                    # current name from the ID with the documented lif/${id} query.
                    $current = Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "lif/$([uri]::EscapeDataString($Id))" | Select-DMResponseData
                    if (-not $current -or -not $current.NAME) {
                        throw "No logical interface with ID '$Id' could be resolved to a name; the modify request was not sent."
                    }
                    $body['NAME'] = [string]$current.NAME
                }
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'lif' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
