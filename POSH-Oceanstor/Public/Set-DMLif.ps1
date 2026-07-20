function Set-DMLif {
    <#
    .SYNOPSIS
        Modifies an OceanStor logical interface port.

    .DESCRIPTION
        The target is addressed by -Id or -Name and the modify is always issued as
        PUT lif/{id}, with the ID carried in the URL path. The array's lif modify
        interface rejects a body that repeats the object's own identity (ID+NAME)
        with error 1077948993 "The object name already exists", so identity is kept
        out of the body entirely -- the ID in the path is the sole target reference.
        When the target is addressed by -Name, the name is first resolved to its ID
        through the documented exact NAME filter.

        To rename an interface, pass -NewName; it is the only value that populates the
        body NAME field. The addressing -Name never enters the body.

        A single interface is modified per call. Piping more than one interface
        (e.g. Get-DMLif 'nas*' | Set-DMLif ...) is rejected before any request is
        sent, because one call carries a single set of changes (for example, one IP
        address) that cannot sensibly be fanned out across several interfaces.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
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
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMLif -WebSession $session).'LIF Name' | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$NewName,

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

    begin {
        # Targets are collected across the pipeline and acted on in end{} so a
        # multi-object pipe can be rejected before any modify is sent -- see the
        # count guard below.
        $targets = [System.Collections.Generic.List[object]]::new()
    }

    process {
        try {
            if (-not $PSBoundParameters.ContainsKey('Id') -and -not $PSBoundParameters.ContainsKey('Name')) {
                throw 'Specify -Id or -Name to identify the logical interface to modify.'
            }
            # Snapshot this pipeline item's identity; the actual modify happens in end{}.
            $targets.Add([pscustomobject]@{
                    Id   = if ($PSBoundParameters.ContainsKey('Id')) { $Id } else { $null }
                    Name = if ($PSBoundParameters.ContainsKey('Name')) { $Name } else { $null }
                })
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }

    end {
        try {
            if ($targets.Count -eq 0) {
                # Nothing bound and nothing piped (or an empty pipeline): no-op.
                return
            }
            if ($targets.Count -gt 1) {
                throw "Set-DMLif received $($targets.Count) logical interfaces from the pipeline. A modify call carries a single set of changes (for example, one IP address), so it cannot be fanned out across multiple interfaces -- this is almost certainly a mistake. Pipe a single interface, or call Set-DMLif once per interface."
            }
            $target = $targets[0]

            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            # Identity (Id/Name) is deliberately absent from this map: the ID is carried
            # in the URL path (PUT lif/{id}) and echoing it -- or the current NAME -- in
            # the body makes the array reject the payload with 1077948993. Only -NewName
            # populates the body NAME field, and only when a rename is requested.
            $body = ConvertTo-DMRequestBody -BoundParameters $PSBoundParameters -Map @{
                NewName               = 'NAME'
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

            # The REST modify interface treats ADDRESSFAMILY as a mandatory body field
            # whenever the addressing changes: an IPv4 edit must carry ADDRESSFAMILY=0 and
            # an IPv6 edit must carry ADDRESSFAMILY=1, or the array rejects the payload.
            # Derive it from the address being changed unless the caller pinned
            # -AddressFamily explicitly (in which case their value is authoritative).
            if (-not $PSBoundParameters.ContainsKey('AddressFamily')) {
                $changingIPv4 = $PSBoundParameters.ContainsKey('IPv4Address')
                $changingIPv6 = $PSBoundParameters.ContainsKey('IPv6Address')
                if ($changingIPv4 -and $changingIPv6) {
                    throw 'Cannot change both -IPv4Address and -IPv6Address in one request; the mandatory ADDRESSFAMILY body field is single-valued. Specify -AddressFamily (0 for IPv4, 1 for IPv6) to disambiguate.'
                }
                elseif ($changingIPv4) {
                    $body['ADDRESSFAMILY'] = 0
                }
                elseif ($changingIPv6) {
                    $body['ADDRESSFAMILY'] = 1
                }
            }

            $displayTarget = if ($target.Name) { $target.Name } else { $target.Id }
            if ($PSCmdlet.ShouldProcess($displayTarget, 'Modify logical interface')) {
                # Resolve the target to an ID for the URL path. Prefer an explicit -Id;
                # otherwise resolve -Name through the documented exact NAME filter. The
                # ID becomes the sole target reference (PUT lif/{id}); it never enters
                # the body.
                if ($target.Id) {
                    $targetId = $target.Id
                }
                else {
                    $lookup = "lif?filter=NAME::$([uri]::EscapeDataString($target.Name))"
                    $found = @(Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $lookup | Select-DMResponseData)
                    if ($found.Count -eq 0 -or -not $found[0].ID) {
                        throw "No logical interface named '$($target.Name)' was found; the modify request was not sent."
                    }
                    if ($found.Count -gt 1) {
                        throw "Multiple logical interfaces named '$($target.Name)' were found; specify -Id to disambiguate."
                    }
                    $targetId = [string]$found[0].ID
                }

                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "lif/$([uri]::EscapeDataString($targetId))" -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
