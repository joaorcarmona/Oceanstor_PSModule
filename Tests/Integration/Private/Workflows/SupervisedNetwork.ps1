# Operator-supervised network-stack mutation workflows (Phase 07). Safety contract
# (see docs/network/safety-and-live-validation.md):
#   - gated behind -RunSupervisedTests AND Network.Enabled AND
#     Network.Supervised.Enabled AND the per-stack Allow* gate; all disabled by
#     default. -RunMutatingTests / -RunSupervisedTests alone never execute a stack.
#   - operates ONLY on the operator-designated ports in
#     Network.Supervised.PortLocations, each re-verified read-only (front-end, link
#     down, unbonded, no LIF, no child VLAN) before anything is created; a failed
#     invariant blocks the stacks loudly instead of touching the port.
#   - only test-owned, run-unique objects (dm_integrity_<runId>_*) are created; each
#     ID is captured from the create call and torn down by that captured ID only.
#   - the idle-port guard (Get-DMVlanParentPortStatus) is invoked and RECORDED as a
#     dry-run, never used to gate: on lab arrays it reports InUse for all ports
#     because the built-in System-defined failover group owns them (CHANGELOG.md, Standing safety reference).
#   - both stacks run sequentially, each with its own inline LIFO teardown in a
#     finally block, so the shared ports are free again before the next stack runs.
#   - pre-existing ports, VLANs, LIFs, bonds and failover groups are never touched.

# Group X: the non-Set network mutators uniquely owned by the supervised workflow
# (bond/VLAN/LIF create+remove). MutationValidation reports these NotRequested /
# NotConfigured when a supervised run is not active; when it is, the stacks below
# represent them (or emit NotConfigured for the ones no enabled stack covers).
$script:SupervisedNetworkStackCommands = @(
    'New-DMPortBond', 'Remove-DMPortBond',
    'New-DMvLan', 'Remove-DMvLan',
    'New-DMLif', 'Remove-DMLif'
)

# Which of the Group X commands each stack represents when it runs. Used to emit
# NotConfigured only for Group X commands that no enabled stack covers (avoids a
# command showing both a NotConfigured row and an execution row). Failover-group
# commands are intentionally excluded here -- they stay owned by the config-gated
# FailoverGroup mutation workflow / its NotRequested fallback; the FG stack merely
# adds extra ':Supervised' execution rows for them.
$script:SupervisedNetworkStackCoverage = @{
    Net = @('New-DMPortBond', 'Remove-DMPortBond', 'New-DMvLan', 'Remove-DMvLan', 'New-DMLif', 'Remove-DMLif')
    Fg  = @('New-DMvLan', 'Remove-DMvLan', 'New-DMLif', 'Remove-DMLif')
}

function Resolve-SupervisedPort {
    param([Parameter(Mandatory)][string]$Location)
    $match = @(Get-DMPortETH -WebSession $session | Where-Object { $_.Location -eq $Location })
    if ($match.Count -ne 1) {
        throw "Supervised port '$Location' resolved to $($match.Count) objects; expected exactly one."
    }
    return $match[0]
}

function Test-SupervisedPortInvariant {
    # Read-only GUARD-STOP checks: the designated port must be front-end, link
    # down, unbonded, host no LIF and parent no VLAN before we create anything.
    param([Parameter(Mandatory)][pscustomobject]$Port)
    $loc = $Port.Location
    if ("$($Port.'Logic Type')" -notmatch 'host port|service port|front') {
        throw "Supervised guard-stop: port $loc logic type '$($Port.'Logic Type')' is not front-end; refusing."
    }
    if ("$($Port.'Running Status' ?? $Port.RunningStatus)" -notmatch 'down') {
        throw "Supervised guard-stop: port $loc is not link down; refusing."
    }
    if ("$($Port.'Port Bond Id')".Trim()) {
        throw "Supervised guard-stop: port $loc is already bonded; refusing."
    }
    # Cross-check bond membership via Get-DMPortBond: the ETH getter's own
    # 'Port Bond Id' field can read blank even when the port is listed in a
    # bond's Ethernet Ports (observed live on 10.10.10.24 with a leftover
    # 'BondTest'). Without this the invariant passes a bonded port and the
    # failure only surfaces later at New-DMvLan (API 1073743391).
    $bondMember = @(Get-DMPortBond -WebSession $session | Where-Object {
        "$($_.'Ethernet Ports')" -match [regex]::Escape([string]$Port.Id)
    })
    if ($bondMember.Count -gt 0) {
        throw "Supervised guard-stop: port $loc is a member of bond '$($bondMember[0].Name)' (its 'Port Bond Id' reads blank but Get-DMPortBond lists it); refusing."
    }
    if (@(Get-DMLif -WebSession $session -HomePortId $Port.Id).Count -gt 0) {
        throw "Supervised guard-stop: port $loc hosts one or more LIFs; refusing."
    }
    if (@(Get-DMvLan -WebSession $session | Where-Object { $_.'Port Id' -eq $Port.Id }).Count -gt 0) {
        throw "Supervised guard-stop: port $loc already parents one or more VLANs; refusing."
    }
}

function Invoke-SupervisedStackTeardown {
    # Removes this stack's created objects strictly by captured ID, in reverse
    # creation order (LIFO). Object removals go through Invoke-OwnedRemoval (which
    # asserts test ownership and clears the owned-set entry); failover-group member
    # associations are not $owned objects, so they are removed via a plain step.
    param([Parameter(Mandatory)][System.Collections.Generic.Stack[pscustomobject]]$Created)
    while ($Created.Count -gt 0) {
        $obj = $Created.Pop()
        switch ($obj.Kind) {
            'Lif' {
                Invoke-OwnedRemoval -Name 'Remove-DMLif:Supervised' -Kind Lif -Identity $obj.Id -Action {
                    Remove-DMLif -WebSession $session -Name $obj.Name -Id $obj.Id -Confirm:$false
                }
            }
            'FgMember' {
                Invoke-MutationStep -Name 'Remove-DMFailoverGroupMember:Supervised' -Category 'Supervised' -Action {
                    Remove-DMFailoverGroupMember -WebSession $session -Id $obj.FgId -AssociateObjectType $obj.AssocType -AssociateObjectId $obj.AssocId -Confirm:$false
                } | Out-Null
            }
            'FailoverGroup' {
                Invoke-OwnedRemoval -Name 'Remove-DMFailoverGroup:Supervised' -Kind FailoverGroup -Identity $obj.Id -Action {
                    Remove-DMFailoverGroup -WebSession $session -Id $obj.Id -Confirm:$false
                }
            }
            'Vlan' {
                Invoke-OwnedRemoval -Name 'Remove-DMvLan:Supervised' -Kind Vlan -Identity $obj.Id -Action {
                    Remove-DMvLan -WebSession $session -Id $obj.Id -Confirm:$false
                }
            }
            'Bond' {
                Invoke-OwnedRemoval -Name 'Remove-DMPortBond:Supervised' -Kind Bond -Identity $obj.Id -Action {
                    Remove-DMPortBond -WebSession $session -Id $obj.Id -Confirm:$false
                }
            }
        }
    }
}

function Write-SupervisedGuardDryRun {
    # Invoke the read-only idle-port guard and record its verdict WITHOUT gating.
    param([Parameter(Mandatory)][pscustomobject[]]$Ports)
    Invoke-MutationStep -Name 'Get-DMVlanParentPortStatus:GuardDryRun' -Category 'Supervised' -Action {
        # 'InUse' is the expected calibration result on lab arrays (the built-in
        # System-defined failover group owns every port); this run proceeds on the
        # operator-designated ports regardless -- the guard result is evidence only.
        foreach ($p in $Ports) {
            $status = Get-DMVlanParentPortStatus -PortId ([string]$p.Id) -WebSession $session
            [pscustomobject]@{
                Location = $p.Location
                PortId   = $p.Id
                Status   = $status.Status
                IsIdle   = $status.IsIdle
                Reasons  = ($status.Reasons -join ' | ')
            }
        }
    } | Out-Null
}

function Invoke-SupervisedNetworkStack {
    # bond(2 ports) -> 4 VLANs (PortType 7, on the bond) -> 4 role-LIFs
    # (HomePortType 8, one per VLAN) -> validate -> inline LIFO teardown.
    param(
        [Parameter(Mandatory)][pscustomobject[]]$Ports,
        [Parameter(Mandatory)]$Sup
    )
    $bondName = New-TestName -Suffix 'bd'
    $tags = @($Sup.VlanTags | Select-Object -First 4)
    $mask = [string]$Sup.IpMask
    # Role codes: 1 = management, 2 = service, 3 = management+service, 4 = replication
    $roleByIndex = @(1, 2, 4, 3)
    $created = [System.Collections.Generic.Stack[pscustomobject]]::new()

    try {
        $bond = @(Invoke-MutationStep -Name 'New-DMPortBond:Supervised' -Category 'Supervised' -Action {
            if (@(Get-DMPortBond -WebSession $session | Where-Object { $_.Name -eq $bondName }).Count -gt 0) {
                throw "A bond named '$bondName' already exists; refusing to claim it test-owned."
            }
            New-DMPortBond -WebSession $session -Name $bondName -PortIdList @($Ports.Id) -Confirm:$false
        })
        if ($bond.Count -eq 0 -or -not $bond[0].Id) { return }
        $bondId = [string]$bond[0].Id
        Register-TestOwnedResource -Kind Bond -Identity $bondId
        $created.Push([pscustomobject]@{ Kind = 'Bond'; Id = $bondId; Name = $bondName })

        $vlanIdByTag = [ordered]@{}
        foreach ($tag in $tags) {
            $currentTag = $tag
            $vlan = @(Invoke-MutationStep -Name 'New-DMvLan:Supervised' -Category 'Supervised' -Action {
                New-DMvLan -WebSession $session -Tag $currentTag -PortType 7 -PortId $bondId -Confirm:$false
            })
            if ($vlan.Count -gt 0 -and $vlan[0].Id) {
                $vid = [string]$vlan[0].Id
                $vlanIdByTag[$currentTag] = $vid
                Register-TestOwnedResource -Kind Vlan -Identity $vid
                $created.Push([pscustomobject]@{ Kind = 'Vlan'; Id = $vid; Name = $vlan[0].Name })
            }
        }

        for ($i = 0; $i -lt $tags.Count; $i++) {
            $tag = $tags[$i]
            if (-not $vlanIdByTag.Contains($tag)) { continue }
            $vid = [string]$vlanIdByTag[$tag]
            $role = $roleByIndex[$i % $roleByIndex.Count]
            $lifName = New-TestName -Suffix "l$tag"
            $ip = ($Sup.IpAddressFormat -f $tag)
            $lif = @(Invoke-MutationStep -Name 'New-DMLif:Supervised' -Category 'Supervised' -Action {
                New-DMLif -WebSession $session -Name $lifName -AddressFamily 0 `
                    -IPv4Address $ip -IPv4Mask $mask -Role $role `
                    -HomePortType 8 -HomePortId $vid -Confirm:$false
            })
            if ($lif.Count -gt 0 -and ($lif[0].'LIF Name' -or $lif[0].Id) -and $lif[0].Id) {
                $lifId = [string]$lif[0].Id
                Register-TestOwnedResource -Kind Lif -Identity $lifId
                $created.Push([pscustomobject]@{ Kind = 'Lif'; Id = $lifId; Name = $lifName })
                Add-MutationReadVerification -Name "New-DMLif:Supervised:$tag" -Category 'SupervisedRead' -ExpectedType 'OceanStorLIF' -Action {
                    @(Get-DMLif -WebSession $session | Where-Object { $_.'LIF Name' -eq $lifName })
                } | Out-Null
            }
        }
    }
    finally {
        Invoke-SupervisedStackTeardown -Created $created
    }
}

function Invoke-SupervisedFailoverGroupStack {
    # 2 VLANs (PortType 1, one per raw port) -> NAS failover group -> add both as
    # members (280) / verify 2 -> modify -> service LIF on VLAN[0] bound to the
    # group -> validate -> inline LIFO teardown (LIF, members, group, VLANs).
    param(
        [Parameter(Mandatory)][pscustomobject[]]$Ports,
        [Parameter(Mandatory)]$Sup
    )
    # A failover group's member VLANs must share ONE tag id: the array rejects
    # mixed tags with error 1073815814 ("VLAN ports with different IDs cannot be
    # added to one failover group"). Use a single tag on both raw ports -- same
    # tag, different ports -- mirroring the production NAS pair (CTE0.A/B.IOM0.P0.50).
    # Live-validated 2026-07-20. (The bond network-stack workflow, by contrast,
    # legitimately uses four distinct tags for four VLANs on one bond.)
    $fgTag = @($Sup.VlanTags | Select-Object -First 1)[0]
    $mask = [string]$Sup.IpMask
    $fgName = New-TestName -Suffix 'fg'
    $lifName = New-TestName -Suffix 'lif'
    $created = [System.Collections.Generic.Stack[pscustomobject]]::new()

    try {
        # ---- one tagged VLAN per raw port, both sharing $fgTag (PortType 1) ----
        $vlanIds = [System.Collections.Generic.List[string]]::new()
        for ($i = 0; $i -lt 2 -and $i -lt $Ports.Count; $i++) {
            $portId = [string]$Ports[$i].Id
            $vlan = @(Invoke-MutationStep -Name 'New-DMvLan:Supervised' -Category 'Supervised' -Action {
                New-DMvLan -WebSession $session -Tag $fgTag -PortType 1 -PortId $portId -Confirm:$false
            })
            if ($vlan.Count -gt 0 -and $vlan[0].Id) {
                $vid = [string]$vlan[0].Id
                $vlanIds.Add($vid)
                Register-TestOwnedResource -Kind Vlan -Identity $vid
                $created.Push([pscustomobject]@{ Kind = 'Vlan'; Id = $vid; Name = $vlan[0].Name })
            }
        }
        if ($vlanIds.Count -lt 2) { return }

        # ---- customized NAS failover group ----
        $fgCreated = @(Invoke-MutationStep -Name 'New-DMFailoverGroup:Supervised' -Category 'Supervised' -Action {
            if (@(Get-DMFailoverGroup -WebSession $session -Name $fgName).Count -gt 0) {
                throw "A failover group named '$fgName' already exists; refusing to claim it test-owned."
            }
            New-DMFailoverGroup -WebSession $session -Name $fgName -Description "Integrity supervised $runId" -FailoverGroupServiceType 0 -Confirm:$false
        })
        if ($fgCreated.Count -eq 0) { return }
        $fg = @(Add-MutationReadVerification -Name 'New-DMFailoverGroup:Supervised:ReadBack' -Category 'SupervisedRead' -ExpectedType 'OceanStorFailoverGroup' -Action {
            @(Get-DMFailoverGroup -WebSession $session -Name $fgName)
        })
        if ($fg.Count -eq 0 -or -not $fg[0].Id) { return }
        $fgId = [string]$fg[0].Id
        Register-TestOwnedResource -Kind FailoverGroup -Identity $fgId
        $created.Push([pscustomobject]@{ Kind = 'FailoverGroup'; Id = $fgId; Name = $fgName })

        # ---- add both VLANs as members (ASSOCIATEOBJTYPE 280 = VLAN) ----
        foreach ($vid in $vlanIds) {
            $memberVid = $vid
            $added = @(Invoke-MutationStep -Name 'Add-DMFailoverGroupMember:Supervised' -Category 'Supervised' -Action {
                Add-DMFailoverGroupMember -WebSession $session -Id $fgId -AssociateObjectType 280 -AssociateObjectId $memberVid -Confirm:$false
            })
            if ($added.Count -ge 0) {
                $created.Push([pscustomobject]@{ Kind = 'FgMember'; FgId = $fgId; AssocType = 280; AssocId = $memberVid; Name = "VLAN member $memberVid" })
            }
        }
        Add-MutationReadVerification -Name 'Get-DMFailoverGroupMember:Supervised' -Category 'SupervisedRead' -Action {
            $members = @(Get-DMFailoverGroupMember -WebSession $session -Id $fgId)
            if ($members.Count -ne 2) {
                throw "The supervised failover group '$fgId' reports $($members.Count) member(s); expected 2."
            }
            $members
        } | Out-Null

        # ---- modify group metadata + read back ----
        Invoke-MutationStep -Name 'Set-DMFailoverGroup:Supervised' -Category 'Supervised' -Action {
            Assert-TestOwnedResource -Kind FailoverGroup -Identity $fgId
            Set-DMFailoverGroup -WebSession $session -Id $fgId -Description "Integrity supervised updated $runId" -Confirm:$false
        } | Out-Null
        Add-MutationReadVerification -Name 'Set-DMFailoverGroup:Supervised:ReadBack' -Category 'SupervisedRead' -ExpectedType 'OceanStorFailoverGroup' -Action {
            $updated = @(Get-DMFailoverGroup -WebSession $session -Id $fgId)
            if ($updated.Count -eq 0 -or $updated[0].Description -ne "Integrity supervised updated $runId") {
                throw "Set-DMFailoverGroup description mismatch on the supervised group '$fgId'."
            }
            $updated
        } | Out-Null

        # ---- service LIF homed on VLAN[0], bound to the group ----
        $homeVid = [string]$vlanIds[0]
        $lifIp = ($Sup.IpAddressFormat -f $fgTag)
        $role = [int]$Sup.LifRole
        $supportProtocol = [int]$Sup.LifSupportProtocol
        $canFailover = [bool]$Sup.LifCanFailover
        $failbackMode = [int]$Sup.LifFailbackMode
        $lif = @(Invoke-MutationStep -Name 'New-DMLif:Supervised' -Category 'Supervised' -Action {
            New-DMLif -WebSession $session -Name $lifName -AddressFamily 0 `
                -IPv4Address $lifIp -IPv4Mask $mask -Role $role -SupportProtocol $supportProtocol `
                -HomePortType 8 -HomePortId $homeVid `
                -FailoverGroupId $fgId -CanFailover $canFailover -FailbackMode $failbackMode -Confirm:$false
        })
        if ($lif.Count -gt 0 -and ($lif[0].'LIF Name' -or $lif[0].Id) -and $lif[0].Id) {
            $lifId = [string]$lif[0].Id
            Register-TestOwnedResource -Kind Lif -Identity $lifId
            $created.Push([pscustomobject]@{ Kind = 'Lif'; Id = $lifId; Name = $lifName })
            Add-MutationReadVerification -Name 'New-DMLif:Supervised:ReadBack' -Category 'SupervisedRead' -ExpectedType 'OceanStorLIF' -Action {
                @(Get-DMLif -WebSession $session | Where-Object { $_.'LIF Name' -eq $lifName })
            } | Out-Null
        }
    }
    finally {
        Invoke-SupervisedStackTeardown -Created $created
    }
}

$script:SupervisedNetworkWorkflow = {
    $network = $configuration.Network
    $sup = $network.Supervised
    $netStackEnabled = [bool]$sup.AllowNetworkStackLifecycle
    $fgStackEnabled = [bool]$sup.AllowFailoverGroupStackLifecycle

    if (-not ($netStackEnabled -or $fgStackEnabled)) {
        # Master gate on but no stack selected: nothing to create, so avoid any
        # live port read and report every supervised command NotConfigured.
        Add-SkippedResult -Name $script:SupervisedNetworkStackCommands -Status 'NotConfigured' -Category 'Supervised' `
            -Reason 'Network.Supervised.Enabled is $true but no stack gate is set. Enable Network.Supervised.AllowNetworkStackLifecycle and/or AllowFailoverGroupStackLifecycle to run a supervised stack.'
        return
    }

    # Resolve + read-only invariant-check the operator-designated ports. Wrapped in
    # a mutation step so a failed invariant records a Blocked result and skips the
    # stacks instead of throwing out of the workflow.
    $ports = @(Invoke-MutationStep -Name 'Resolve-SupervisedPorts' -Category 'Supervised' -Action {
        $resolved = foreach ($loc in $sup.PortLocations) { Resolve-SupervisedPort -Location $loc }
        foreach ($p in $resolved) { Test-SupervisedPortInvariant -Port $p }
        $resolved
    })

    if ($ports.Count -lt 2) {
        Add-SkippedResult -Name $script:SupervisedNetworkStackCommands -Status 'Blocked' -Category 'Supervised' `
            -Reason 'The operator-designated supervised ports could not be resolved or failed their read-only idle invariants; no supervised network object was created.'
        return
    }

    if ($sup.RecordGuardDryRun) { Write-SupervisedGuardDryRun -Ports $ports }

    if ($netStackEnabled) { Invoke-SupervisedNetworkStack -Ports $ports -Sup $sup }
    if ($fgStackEnabled) { Invoke-SupervisedFailoverGroupStack -Ports $ports -Sup $sup }

    # NotConfigured only for Group X commands that no ENABLED stack represents, so a
    # command never shows both a NotConfigured row and an execution row.
    $covered = @()
    if ($netStackEnabled) { $covered += $script:SupervisedNetworkStackCoverage.Net }
    if ($fgStackEnabled) { $covered += $script:SupervisedNetworkStackCoverage.Fg }
    $covered = @($covered | Select-Object -Unique)
    $notConfigured = @($script:SupervisedNetworkStackCommands | Where-Object { $_ -notin $covered })
    if ($notConfigured.Count -gt 0) {
        Add-SkippedResult -Name $notConfigured -Status 'NotConfigured' -Category 'Supervised' `
            -Reason 'Enable the relevant Network.Supervised.Allow* stack gate (AllowNetworkStackLifecycle covers bond/VLAN/LIF; AllowFailoverGroupStackLifecycle covers VLAN/LIF) to exercise these commands.'
    }
}
