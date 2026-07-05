function New-DMLif {
    <#
    .SYNOPSIS
        Creates an OceanStor logical interface port.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [string]$IPv4Address,
        [string]$IPv4Mask,
        [string]$IPv4Gateway,
        [string]$IPv6Address,
        [string]$IPv6Mask,
        [string]$IPv6Gateway,

        [ValidateSet(1, 2, 3, 4, 8, 9, 10)]
        [int]$Role,

        [ValidateSet(0, 1, 2, 3, 4, 8, 64, 512)]
        [int]$SupportProtocol,

        [Parameter(Mandatory = $true)]
        [ValidateSet(1, 7, 8, 25, 26)]
        [int]$HomePortType,

        [string]$HomePortId,
        [string]$HomePortName,
        [string]$HomeControllerId,
        [bool]$OperationalStatus,

        [Parameter(Mandatory = $true)]
        [ValidateSet(0, 1)]
        [int]$AddressFamily,

        [bool]$IsPrivate,
        [string]$FailoverGroupId,
        [bool]$CanFailover,
        [ValidateSet(0, 1, 2)]
        [int]$FailbackMode,
        [string]$VstoreId,
        [ValidateSet(0, 1, 2)]
        [int]$DdnsStatus,
        [string]$DnsZoneName,
        [ValidateSet(0, 1)]
        [int]$ListenDnsQueryEnabled,
        [string]$HomeSiteWwn
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
        Name                  = 'NAME'
        IPv4Address           = 'IPV4ADDR'
        IPv4Mask              = 'IPV4MASK'
        IPv4Gateway           = 'IPV4GATEWAY'
        IPv6Address           = 'IPV6ADDR'
        IPv6Mask              = 'IPV6MASK'
        IPv6Gateway           = 'IPV6GATEWAY'
        Role                  = 'ROLE'
        SupportProtocol       = 'SUPPORTPROTOCOL'
        HomePortType          = 'HOMEPORTTYPE'
        HomePortId            = 'HOMEPORTID'
        HomePortName          = 'HOMEPORTNAME'
        HomeControllerId      = 'HOMECONTROLLERID'
        OperationalStatus     = 'OPERATIONALSTATUS'
        AddressFamily         = 'ADDRESSFAMILY'
        IsPrivate             = 'ISPRIVATE'
        FailoverGroupId       = 'FAILOVERGROUPID'
        CanFailover           = 'CANFAILOVER'
        FailbackMode          = 'FAILBACKMODE'
        VstoreId              = 'vstoreId'
        DdnsStatus            = 'ddnsStatus'
        DnsZoneName           = 'dnsZoneName'
        ListenDnsQueryEnabled = 'listenDnsQueryEnabled'
        HomeSiteWwn           = 'HOMESITEWWN'
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create logical interface')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'lif' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0 -and $response.data) {
            return [OceanStorLIF]::new($response.data, $session)
        }

        return $response.error
    }
}
