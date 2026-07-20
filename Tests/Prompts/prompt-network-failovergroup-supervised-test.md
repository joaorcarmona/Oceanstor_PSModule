# Prompt: supervised failover-group lifecycle + VLAN members + service LIF live validation

Paste this whole file as the task prompt in a new Claude Code session against this repo
(`POSH-Oceanstor`) to run the first operator-supervised, config-gated live validation of the
**failover-group NAS front-end stack**: two test-owned VLANs on two designated down ports →
a customized NAS failover group → both VLANs added/removed as members → one service LIF homed
on a member VLAN and bound to the group. This closes the tracked gaps in
`docs/network/TODO.md` "Current Focus" (FG lifecycle) and "Medium Priority" (member
add/remove — previously blocked because the harness owned no eligible member).

## Persona / ground rules (must hold for the whole session)

- Act as a senior storage administrator / cautious validation engineer.
- Never print, log, or write to any file the credential object, password, session token,
  cookie, or auth header. Load creds with:
  ```powershell
  $cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
  ```
- Do not push, tag, publish, merge, rebase, switch branches, or create branches.
- Use only test-owned objects with a unique prefix (`dm_integrity_<runId>_`). Capture every
  created object's ID immediately from a read-back. Clean up strictly by captured ID, in a
  `finally` block, in **exact reverse creation order** (LIFO): LIF → failover-group members →
  failover group → VLANs.
- Never broad-clean by name pattern against the live array outside of the objects this run
  itself created. Never touch any pre-existing object (LIFs, VLANs, bonds, failover groups —
  especially the built-in `System-defined` group — users, roles, SNMP/syslog/NTP/DNS,
  replication/HyperMetro pairs, etc.).
- If cleanup fails or ordering is unclear, stop and report — do not improvise a broader delete.
- Do not put the lab IP in any public doc; only the scratch script (not committed) may use it.
  Public doc examples must use `$storageIP = 'StorageIP'`.
- Commit at the end with a clear message once evidence is written to
  `docs/network/TODO.md`. Do not push.

## Inputs the operator supplies at run time

- **Two currently link-down front-end ports**, re-verified read-only before anything is touched.
  Reuse the same ports between supervised runs. **Ideally one per controller** (e.g.
  `CTE0.A.IOM0.P2` and `CTE0.B.IOM0.P2`) so the failover group spans controllers; if only
  same-controller down ports are available the workflow still validates the full cmdlet path.
- **VLAN tag 130** — a single tag shared by **both** member VLANs. A failover group requires
  all member VLANs to share the same tag id (array error `1073815814` otherwise); the group
  spans that one tag across the two ports (as the production NAS pair does with tag 50).
- **IP scheme `10.<tag>.10.X/24`** ⇒ mask `255.255.255.0`; the service LIF takes host `.1`
  on its home VLAN's subnet (`10.130.10.1/24`).

## Task

On the lab array (`10.10.10.24`), using the two operator-designated link-down front-end ports
(front-end = `'Logic Type'` value `host port/service port`; re-verify read-only before touching
anything):

1. **Idle-port guard dry-run (record only, does NOT gate).** Invoke the read-only guard
   `Get-DMVlanParentPortStatus` against both designated ports and record its output. On this
   array the guard reports `InUse` for every port because the built-in `System-defined`
   failover group contains all ports (see `docs/network/TODO.md` guard-calibration finding), so
   it can never green-light a port here. This step **confirms that calibration finding** and
   then proceeds anyway **because the ports are operator-designated** — the guard result is
   evidence, not a gate.
2. Create VLAN `130` on **both** designated ports (same tag, one per port), each with
   `New-DMvLan -PortType 1` (VLAN on an Ethernet parent port). Capture each VLAN's ID from a
   read-back. (Member VLANs must share one tag — see Inputs.)
3. Create a customized **NAS** failover group with a run-unique name
   (`New-DMFailoverGroup -FailoverGroupServiceType 0`). Read it back, capture its ID (shaped
   like `289:<n>`), and register cleanup **before** the next step.
4. Add **both VLANs** as members (`Add-DMFailoverGroupMember -AssociateObjectType 280
   -AssociateObjectId <vlanId>`). Then `Get-DMFailoverGroupMember -Id <fgId>` and confirm it
   reports **exactly 2** members.
5. Modify the group metadata (`Set-DMFailoverGroup -Id <fgId> -Description ...`) and read back
   to confirm the description changed.
6. Create one **service** LIF homed on VLAN `130` and bound to the group:
   `New-DMLif -AddressFamily 0 -IPv4Address '10.130.10.1' -IPv4Mask '255.255.255.0'
   -Role 2 -SupportProtocol 3 -HomePortType 8 -HomePortId <vlan130Id>
   -FailoverGroupId <fgId> -CanFailover $true -FailbackMode 1`
   (`Role 2` = service, `SupportProtocol 3` = NFS+CIFS, `HomePortType 8` = home on a VLAN,
   `FailbackMode 1` = manual). Capture the LIF's ID.
7. Validate everything: read back the group (description), the member list (2), and the LIF
   (role, IP, mask, home VLAN, **and its failover binding** — `Failover Group Id` /
   `Can Failover`). Record the failover-binding fields even if they read back empty (possible
   class field-mapping gap — log as `NeedsInvestigation`, do not fail the run on it; gate LIF
   success on `'LIF Name'`/`.Id` + IP instead).
8. **Remove one member and re-verify** the getter now reports 1, to exercise
   `Remove-DMFailoverGroupMember` as a discrete step (the remaining member is also removed
   during teardown).
9. Tear down in exact reverse creation order (LIFO), unconditionally from a `finally` block:
   LIF (by ID) → remaining failover-group member(s) → failover group (by ID) → VLAN 131 →
   VLAN 130 (each by captured ID). Verify zero leftover test objects and that both ports are
   back to link-down / unbonded / no child VLAN afterward.
10. Record the outcome in `docs/network/TODO.md` (guard dry-run result, member add/remove
    behavior, LIF failover-binding read-back, any new field-mapping findings) and commit
    (no push).

## Known pitfalls (carry these forward)

- **Failover-group members are ports, not LIFs.** `ASSOCIATEOBJTYPE` `213` = Ethernet port,
  `235` = bond port, `280` = VLAN. This run uses `280` (VLANs). The member *getter* queries
  per type with `ASSOCIATEOBJTYPE=289` (the failover-group object type) — that is expected,
  not a typo.
- **Delete members before the group, group before the VLANs, LIF before everything.** The
  array refuses to remove a VLAN while a LIF is homed on it (`1073813505`); a VLAN that is
  still a failover-group member may also refuse removal until the association is cleared.
- **`Remove-DMFailoverGroupMember` reports API failures as non-terminating**
  (`catch { WriteError }`) — a failed member removal will not throw. During teardown, catch and
  report each result, and let the after-cleanup verification surface any leftover association
  (a still-attached member will then block the VLAN removal). Do not assume success from a
  silent return.
- **`OceanStorLIF` has no `Name` property** — the LIF name is only exposed as `'LIF Name'`
  (`$lif.'LIF Name'`). Gate LIF-create success on `'LIF Name'` or `.Id`, never `$lif.Name`.
- **`Get-DMvLan`'s `Tag` reads empty** — match VLANs by `Name` (`<port>.<tag>` suffix, e.g.
  `\.130$`), not by `Tag`.
- Port "front-end" surfaces as `'Logic Type'` (not `'Logical Type'`) with value
  `host port/service port`.
- The LIF's `Failover Group Id` / `Can Failover` fields may not surface on read-back if the
  `OceanStorLIF` class does not map them (same field-mapping family as the `Tag` / `Port List`
  gaps). Record what you see and flag `NeedsInvestigation`; do not fail the run solely on a
  missing failover field.

## Reference implementation (scratch script — save under the session scratchpad, NOT committed)

Run it interactively so you can watch each phase before cleanup fires.

```powershell
# Supervised, operator-authorized failover-group NAS front-end lifecycle validation.
# VLAN130(port0)+VLAN131(port1) -> NAS failover group -> both VLANs as members (280) ->
# service LIF on VLAN130 bound to the group -> validate -> remove one member -> teardown
# in exact reverse creation order (LIFO, in finally).
$ErrorActionPreference = 'Stop'

Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$s = Connect-deviceManager -Hostname '10.10.10.24' -PassThru -Credential $cred -SkipCertificateCheck

# Operator-designated: two currently link-down front-end ports, ideally one per controller.
$targetLocations = @('CTE0.A.IOM0.P2', 'CTE0.B.IOM0.P2')
$runId = Get-Date -Format yyyyMMddHHmmss
$mask = '255.255.255.0'
$fgName  = "dm_integrity_${runId}_fg"
$lifName = "dm_integrity_${runId}_lif"
# A failover group requires all member VLANs to share the SAME tag id (array
# error 1073815814 when tags differ). Same tag on different ports is valid and is
# how the production NAS pair is built (CTE0.A/B.IOM0.P0.50). So: tag 130 on both.
$vlanPlan = @(
    @{ Tag = 130; PortIndex = 0 },
    @{ Tag = 130; PortIndex = 1 }
)
# Service LIF homes on VLAN130's subnet, host .1.
$lifIp = '10.130.10.1'

# The idle-port guard is a Private helper; invoke it inside the module scope.
$mod = Get-Module POSH-Oceanstor
function Invoke-PortGuard { param($portId) & $mod { param($id, $sess) Get-DMVlanParentPortStatus -PortId $id -WebSession $sess } $portId $s }

# LIFO stack of created objects/associations for reverse-order teardown.
$created = [System.Collections.Generic.Stack[pscustomobject]]::new()

try {
    # ---- Phase A: read-only invariants on both designated ports ----
    $ethPorts = @(Get-DMPortETH -WebSession $s)
    $ports = foreach ($loc in $targetLocations) {
        $match = @($ethPorts | Where-Object { $_.Location -eq $loc })
        if ($match.Count -ne 1) { throw "GUARD-STOP: port '$loc' resolved to $($match.Count) objects; expected exactly 1." }
        $match[0]
    }
    $allVlans = @(Get-DMvLan -WebSession $s)
    $allLifs  = @(Get-DMLif -WebSession $s)
    $allFgs   = @(Get-DMFailoverGroup -WebSession $s)
    Write-Output ("SNAPSHOT: vlans={0} lifs={1} failovergroups={2}" -f $allVlans.Count, $allLifs.Count, $allFgs.Count)

    foreach ($p in $ports) {
        if ("$($p.'Logic Type')" -notmatch 'host port|service port|front') { throw "GUARD-STOP: $($p.Location) logic type '$($p.'Logic Type')' not front-end; refusing." }
        if ("$($p.'Running Status' ?? $p.RunningStatus)" -notmatch 'down') { throw "GUARD-STOP: $($p.Location) is not link down; refusing." }
        if ("$($p.'Port Bond Id')".Trim()) { throw "GUARD-STOP: $($p.Location) already bonded; refusing." }
        if (@(Get-DMLif -WebSession $s -HomePortId $p.Id).Count -gt 0) { throw "GUARD-STOP: $($p.Location) hosts LIF(s); refusing." }
        if (@($allVlans | Where-Object { $_.'Port Id' -eq $p.Id }).Count -gt 0) { throw "GUARD-STOP: $($p.Location) parents VLAN(s); refusing." }
        Write-Output ("INVARIANTS OK {0}: Id={1} front-end, link down, unassociated" -f $p.Location, $p.Id)
    }
    foreach ($v in $vlanPlan) {
        if (@($allVlans | Where-Object { "$($_.Tag)" -eq "$($v.Tag)" -or $_.Name -match "\.$($v.Tag)$" }).Count -gt 0) { throw "GUARD-STOP: pre-existing VLAN tag $($v.Tag) found; refusing." }
    }
    if (@($allLifs | Where-Object { $_.'IPv4 Address' -eq $lifIp -or $_.IPV4ADDR -eq $lifIp }).Count -gt 0) { throw "GUARD-STOP: pre-existing LIF already uses $lifIp; refusing." }
    if (@($allFgs | Where-Object { $_.Name -eq $fgName }).Count -gt 0) { throw "GUARD-STOP: failover group '$fgName' already exists; refusing." }
    Write-Output "PRECHECK: no tag/IP/name collisions."

    # ---- Phase A2: idle-port guard DRY-RUN (record only, does NOT gate) ----
    Write-Output '--- GUARD DRY-RUN (record only) ---'
    foreach ($p in $ports) {
        $g = Invoke-PortGuard $p.Id
        Write-Output ("GUARD {0} (Id={1}): Status={2} IsIdle={3} Reasons=[{4}]" -f $p.Location, $p.Id, $g.Status, $g.IsIdle, ($g.Reasons -join ' | '))
    }
    Write-Output "GUARD NOTE: 'InUse' here is expected (System-defined group owns all ports); proceeding on operator-designated ports."

    # ---- Phase B1: VLANs on the two designated ports (PortType 1 = VLAN on Ethernet) ----
    $vlanByIndex = @{}   # keyed by PortIndex (0/1) since both share tag 130
    foreach ($v in $vlanPlan) {
        $portId = [string]$ports[$v.PortIndex].Id
        $vlan = New-DMvLan -WebSession $s -Tag $v.Tag -PortType 1 -PortId $portId -Confirm:$false
        if (-not $vlan -or -not $vlan.Id) { throw "CREATE-FAIL: VLAN $($v.Tag) returned no ID." }
        $created.Push([pscustomobject]@{ Kind = 'Vlan'; Id = [string]$vlan.Id; Name = $vlan.Name })
        $vlanByIndex[$v.PortIndex] = $vlan
        Write-Output ("CREATED VLAN{0} Id={1} Name={2} on {3}" -f $v.Tag, $vlan.Id, $vlan.Name, $ports[$v.PortIndex].Location)
    }

    # ---- Phase B2: customized NAS failover group ----
    $null = New-DMFailoverGroup -WebSession $s -Name $fgName -Description "Integrity supervised run $runId" -FailoverGroupServiceType 0 -Confirm:$false
    $fg = @(Get-DMFailoverGroup -WebSession $s -Name $fgName)[0]
    if (-not $fg -or -not $fg.Id) { throw "CREATE-FAIL: failover group '$fgName' not read back with an ID." }
    $fgId = [string]$fg.Id
    $created.Push([pscustomobject]@{ Kind = 'FailoverGroup'; Id = $fgId; Name = $fgName })
    Write-Output ("CREATED FG Id={0} Name={1}" -f $fgId, $fgName)

    # ---- Phase B3: add both VLANs as members (ASSOCIATEOBJTYPE 280 = VLAN) ----
    foreach ($v in $vlanPlan) {
        $vid = [string]$vlanByIndex[$v.PortIndex].Id
        Add-DMFailoverGroupMember -WebSession $s -Id $fgId -AssociateObjectType 280 -AssociateObjectId $vid -Confirm:$false
        $created.Push([pscustomobject]@{ Kind = 'FgMember'; FgId = $fgId; AssocType = 280; AssocId = $vid; Name = "VLAN130@P$($v.PortIndex)" })
        Write-Output ("ADDED MEMBER VLAN130@P{0} (Id={1}) to FG {2}" -f $v.PortIndex, $vid, $fgId)
    }
    $members = @(Get-DMFailoverGroupMember -WebSession $s -Id $fgId)
    Write-Output ("VALIDATE MEMBERS: count={0} (expected 2)" -f $members.Count)
    if ($members.Count -ne 2) { throw "VALIDATE-FAIL: failover group reports $($members.Count) members, expected 2." }

    # ---- Phase B4: modify group metadata + read back ----
    Set-DMFailoverGroup -WebSession $s -Id $fgId -Description "Integrity supervised updated $runId" -Confirm:$false
    $fgRb = @(Get-DMFailoverGroup -WebSession $s -Id $fgId)[0]
    Write-Output ("VALIDATE FG MODIFY: Description='{0}'" -f $fgRb.Description)
    if ($fgRb.Description -ne "Integrity supervised updated $runId") { throw "VALIDATE-FAIL: Set-DMFailoverGroup description did not apply." }

    # ---- Phase B5: service LIF homed on VLAN130, bound to the group ----
    $vlan130Id = [string]$vlanByIndex[0].Id   # port-A tag-130 VLAN hosts the service LIF
    $lif = New-DMLif -WebSession $s -Name $lifName -AddressFamily 0 `
        -IPv4Address $lifIp -IPv4Mask $mask -Role 2 -SupportProtocol 3 `
        -HomePortType 8 -HomePortId $vlan130Id `
        -FailoverGroupId $fgId -CanFailover $true -FailbackMode 1 -Confirm:$false
    if (-not $lif -or -not ($lif.'LIF Name' ?? $lif.Id)) { throw "CREATE-FAIL: LIF $lifName returned no object." }
    $lifId = [string]($lif.Id ?? '')
    $created.Push([pscustomobject]@{ Kind = 'Lif'; Id = $lifId; Name = $lifName })
    Write-Output ("CREATED LIF {0} Id={1} Role=service Ip={2} HomeVLAN=130 FG={3}" -f $lifName, $lifId, $lifIp, $fgId)

    # ---- Phase B6: validation read-backs ----
    Write-Output '--- VALIDATION ---'
    $lifRb = @(Get-DMLif -WebSession $s | Where-Object { $_.'LIF Name' -eq $lifName })
    if ($lifRb.Count -ne 1) { throw "VALIDATE-FAIL: LIF $lifName not found on read-back." }
    $l = $lifRb[0]
    Write-Output ("VALIDATE LIF {0}: Role={1} Ip={2} Mask={3} HomePort={4} FGId='{5}' CanFailover='{6}'" -f `
        $lifName, ($l.Role ?? $l.ROLE), ($l.'IPv4 Address' ?? $l.IPV4ADDR), ($l.'IPv4 Mask' ?? $l.IPV4MASK), `
        ($l.'Home Port Name' ?? $l.HOMEPORTNAME), ($l.'Failover Group Id' ?? $l.FAILOVERGROUPID ?? ''), ($l.'Can Failover' ?? $l.CANFAILOVER ?? ''))
    if (-not (($l.'Failover Group Id' ?? $l.FAILOVERGROUPID))) {
        Write-Output "NOTE(NeedsInvestigation): LIF read-back does not surface a Failover Group Id field; possible OceanStorLIF field-mapping gap."
    }
    Write-Output 'RESULT: FG + members + service LIF create/validate Passed'

    # ---- Phase B7: remove one member, re-verify getter now reports 1 ----
    Write-Output '--- MEMBER REMOVE (discrete step) ---'
    $vlanBId = [string]$vlanByIndex[1].Id   # remove the port-B member (no LIF on it)
    Remove-DMFailoverGroupMember -WebSession $s -Id $fgId -AssociateObjectType 280 -AssociateObjectId $vlanBId -Confirm:$false
    # Non-terminating on API failure: verify by read-back, do not trust the silent return.
    $membersAfter = @(Get-DMFailoverGroupMember -WebSession $s -Id $fgId)
    Write-Output ("VALIDATE MEMBER REMOVE: count={0} (expected 1)" -f $membersAfter.Count)
    if ($membersAfter.Count -eq 1) {
        # Port-B VLAN's association is gone; drop its teardown entry so cleanup doesn't double-remove.
        $remaining = [System.Collections.Generic.Stack[pscustomobject]]::new()
        foreach ($o in $created.ToArray()[($created.Count-1)..0]) {
            if (-not ($o.Kind -eq 'FgMember' -and $o.AssocId -eq $vlanBId)) { $remaining.Push($o) }
        }
        $created = $remaining
        Write-Output "MEMBER REMOVE Passed (port-B VLAN detached; teardown will remove port-A member, FG, then both VLANs)."
    }
    else {
        Write-Output "WARN: member count after remove is $($membersAfter.Count), not 1 — teardown will still attempt full cleanup by captured IDs."
    }
}
finally {
    Write-Output '--- TEARDOWN (reverse creation order) ---'
    while ($created.Count -gt 0) {
        $obj = $created.Pop()
        try {
            switch ($obj.Kind) {
                'Lif'           { if ($obj.Id) { Remove-DMLif -WebSession $s -Name $obj.Name -Id $obj.Id -Confirm:$false } else { Remove-DMLif -WebSession $s -Name $obj.Name -Confirm:$false } }
                'FgMember'      { Remove-DMFailoverGroupMember -WebSession $s -Id $obj.FgId -AssociateObjectType $obj.AssocType -AssociateObjectId $obj.AssocId -Confirm:$false }
                'FailoverGroup' { Remove-DMFailoverGroup -WebSession $s -Id $obj.Id -Confirm:$false }
                'Vlan'          { Remove-DMvLan -WebSession $s -Id $obj.Id -Confirm:$false }
            }
            Write-Output ("CLEANUP: removed {0} {1} (Id={2})" -f $obj.Kind, $obj.Name, ($obj.Id ?? $obj.AssocId))
        }
        catch {
            Write-Output ("CLEANUP-FAILED: {0} {1} :: {2}" -f $obj.Kind, $obj.Name, $_.Exception.Message)
        }
    }
    try {
        $leftLifs  = @(Get-DMLif -WebSession $s | Where-Object { $_.'LIF Name' -like "dm_integrity_${runId}_*" })
        $leftFgs   = @(Get-DMFailoverGroup -WebSession $s | Where-Object { $_.Name -eq $fgName })
        $leftVlans = @(Get-DMvLan -WebSession $s | Where-Object { $_.Name -match '\.(130|131)$' })
        Write-Output ("VERIFY-AFTER-CLEANUP: test LIFs={0} test FGs={1} test VLANs={2}" -f $leftLifs.Count, $leftFgs.Count, $leftVlans.Count)
        foreach ($loc in $targetLocations) {
            $p = @(Get-DMPortETH -WebSession $s | Where-Object Location -eq $loc)[0]
            Write-Output ("VERIFY-PORT {0}: Running={1} BondId='{2}'" -f $p.Location, ($p.'Running Status' ?? $p.RunningStatus), $p.'Port Bond Id')
        }
    }
    catch { Write-Output "VERIFY-AFTER-CLEANUP failed: $($_.Exception.Message)" }
    try { Disconnect-deviceManager -WebSession $s -Confirm:$false } catch { Write-Output "disconnect failed: $($_.Exception.Message)" }
}
```

## Expected report at the end

- Pre-flight invariant results for both designated ports.
- **Guard dry-run** result per port (Status/IsIdle/Reasons), with the note that `InUse` is the
  expected calibration outcome and did not gate the run.
- Created object IDs (2 VLANs, failover group, service LIF).
- Member add result — getter reports **2**; group description modify read-back.
- LIF read-back (role/IP/mask/home VLAN) **and** its failover binding (`Failover Group Id` /
  `Can Failover`), stated plainly — including whether those fields surfaced at all
  (`NeedsInvestigation` if not).
- Discrete member-remove result — getter reports **1** — based on read-back, not the call's
  silent return.
- Teardown order and zero-leftover verification (LIFs / FGs / VLANs = 0; both ports back to
  link-down / unbonded / no child VLAN).
- Any new/repeated field-mapping findings, logged as `NeedsInvestigation` in
  `docs/network/TODO.md` (do not fix them as part of this validation task unless separately
  asked).
- Commit hash, with confirmation nothing was pushed and no pre-existing object was touched.
