# Network Safety and Live Validation

Network cmdlets can break management access, NAS/iSCSI data access, or
failover behavior. This page defines what may run against a live array and
under which rules. When in doubt: **read-only is fine, everything else is
not.**

## Safety classification

| Class | Cmdlets | Live validation rule |
|---|---|---|
| ReadOnlyNetworkInventory | `Get-DMPortETH`, `Get-DMPortFc`, `Get-DMPortSAS`, `Get-DMInterfaceModule`, `Get-DMPortBond`, `Get-DMvLan`, `Get-DMLif`, `Get-DMFailoverGroup` | Safe to run live |
| ReadOnlyNetworkStatus | `Get-DMLLDPWorkingMode` | Safe to run live |
| TestOwnedLogicalNetworkMutation | `New-DMFailoverGroup`, `Set-DMFailoverGroup`, `Remove-DMFailoverGroup`, `Add-DMFailoverGroupMember`, `Remove-DMFailoverGroupMember` | Only on objects created by the same run, with guaranteed cleanup |
| VlanMutation | `New-DMvLan`, `Set-DMvLan`, `Remove-DMvLan` | Only a test-owned VLAN on a verified-idle port; otherwise skip |
| DataAccessMutation / ManagementAccessMutation | `New-DMLif`, `Set-DMLif`, `Remove-DMLif` | Do not run live by default |
| BondOrAggregationMutation | `New-DMPortBond`, `Set-DMPortBond`, `Remove-DMPortBond` | Do not run live by default |
| Global network setting | `Set-DMLLDPWorkingMode` | Do not run live by default (no test-owned variant exists) |

There are **no** physical-port or route/gateway mutation cmdlets in this
module; those classes stay unimplemented on purpose.

## Rules

1. Read-only inventory and status getters are normally safe against any array.
2. Physical port changes (enable/disable, MTU, IP, role) are unsafe by default
   — and not implemented here.
3. Management IP and routing changes are unsafe by default — not implemented.
4. Data-access network changes (LIF addresses, home ports, operational status)
   are unsafe by default.
5. Bond, VLAN, and logical-port mutations require a test-owned workflow:
   - use a unique test name prefix (for example `psoceanstor-test-<runid>-`);
   - capture object IDs **immediately** after creation from the returned
     object;
   - clean up in `finally`;
   - delete by captured ID, never by broad name matching;
   - no broad cleanup, ever.
6. Never modify or delete a pre-existing network object or setting. Existing
   configuration is read-only unless the object was provably created by the
   current run.
7. If cleanup fails, report the object type, ID, and name, and suggest the
   exact manual cleanup command.
8. If a test would require changing an existing global or physical network
   setting (LLDP mode, port MTU, existing VLANs/bonds/LIFs), do not run it
   live — mark it unsafe and note what a dedicated lab would need.

## Recommended staged validation order

1. `Connect-deviceManager` (session only).
2. All read-only network getters (`Get-DMPortETH`, `Get-DMPortBond`,
   `Get-DMvLan`, `Get-DMLif`, `Get-DMFailoverGroup`,
   `Get-DMLLDPWorkingMode`, …).
3. `-WhatIf` dry runs of mutators — confirms parameter binding without any
   API call.
4. (Config-gated, dedicated lab only) test-owned failover-group
   create → modify → member add/remove → delete, by captured IDs.
5. (Dedicated lab only) test-owned VLAN / LIF / bond workflows on
   verified-idle ports.

## Example: safe live session

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only inventory — allowed
Get-DMPortETH -WebSession $storage
Get-DMFailoverGroup -WebSession $storage

# Dry run — allowed (no API call is made)
New-DMFailoverGroup -WebSession $storage -Name 'psoceanstor-test-fg' -WhatIf

Disconnect-deviceManager -WebSession $storage
```

## Example: test-owned pattern (dedicated lab only)

```powershell
$fg = $null
try {
    $fg = New-DMFailoverGroup -WebSession $storage -Name "psoceanstor-test-fg-$runId"
    # ... assertions against $fg ...
}
finally {
    if ($fg -and $fg.Id) {
        Remove-DMFailoverGroup -WebSession $storage -Id $fg.Id -Confirm:$false
    }
}
```

## Relationship to the integrity harness

`Tests/Integration/Invoke-GetterIntegrityValidation.ps1` runs the read-only
network getters (including `Get-DMFailoverGroupMember`) as part of read
validation. On the mutation side there is exactly one network workflow,
disabled by default:

- **Failover-group lifecycle**
  (`Tests/Integration/Private/Workflows/FailoverGroup.ps1`): requires
  `-RunMutatingTests` **and** `AllowMutatingTests = $true` **and**
  `Network.Enabled = $true` **and**
  `Network.AllowFailoverGroupLifecycle = $true` in
  `IntegrityValidationConfig.psd1`. `-RunMutatingTests` alone never runs it.
  It creates one run-unique customized failover group, captures its ID from
  an immediate read-back, registers cleanup before any further step, modifies
  the description, verifies `Get-DMFailoverGroupMember` reports zero members,
  and removes the group by the captured ID. It never touches pre-existing
  groups, LIFs, VLANs, bonds, ports, routes, or management addressing, and a
  name collision aborts the step loudly.
- **Member add/remove inside that workflow is skipped by design**: per the
  REST reference, failover-group members are Ethernet ports (213), bond ports
  (235) or VLANs (280) — not LIFs — and the harness owns no such object. The
  step stays `SkippedUnsafe` until a test-owned VLAN workflow (below) exists.

All other network mutators (`New/Set/Remove-DMPortBond`, `New/Set/Remove-DMvLan`,
`New/Set/Remove-DMLif`, `Set-DMLLDPWorkingMode`) are reported `SkippedUnsafe`
on every run; an intentionally skipped unsafe mutator is not a validated one.
Statuses:

- `SkippedUnsafe` — recognized as unsafe to run against a live array.
- `NotConfigured` — the relevant gate(s) in
  `IntegrityValidationConfig.psd1` (`AllowMutatingTests`, `Network.Enabled`,
  `Network.AllowFailoverGroupLifecycle`) are off.
- `NotRequested` — runner invoked without `-RunMutatingTests`.
- `Blocked` / `NotExecuted` — command has no workflow representation.

## VLAN live workflow: idle-port guard (implemented, workflow not enabled)

A future VLAN live workflow (create/delete a tagged child interface on a
verified-idle port) stays **disabled**. The idle-port guard it depends on is
now implemented and unit-tested as the private helper
`Get-DMVlanParentPortStatus`; the live create/delete run remains deferred to a
separate, supervised session.

1. **Idle-port detection (implemented).** `Get-DMVlanParentPortStatus -PortId
   <id>` inspects a candidate port read-only and returns a structured status
   (`PortId`, `IsIdle`, `Status`, `Reasons`, `CheckedAssociations`). It reports
   `InUse` if *any* association is found — a LIF homed on the port
   (`Get-DMLif -HomePortId`), a VLAN parented on it (`Get-DMvLan` `Port Id`),
   bond membership (`Get-DMPortBond` `Ethernet Ports`), or failover-group
   membership (`Get-DMFailoverGroupMember` across all groups). It reports
   `Status = Idle` (`IsIdle = $true`) **only** when every check completed and
   found nothing.
2. **Unknown is unsafe.** Any inspection failure yields `Status = Unknown`
   (`IsIdle = $false`) with the error captured in `Reasons`; the guard never
   reports `Idle` without positively confirming each checked association is
   empty. Callers must treat both `InUse` and `Unknown` as "do not use".
3. **Gate.** `Network.AllowVlanLifecycle` is defined in
   `IntegrityValidationConfig.psd1` and defaults to `$false`. Enabling it alone
   does nothing: a live VLAN workflow additionally requires a parent port the
   guard positively confirms is `Idle`, and the harness owns no such port yet.
4. **Evidence still required before a live run.** Unit tests for the guard now
   exist (`Tests/Unit/Private/Get-DMVlanParentPortStatus.Tests.ps1`). A dry run
   against a lab array classifying busy vs. idle ports and a human-reviewed run
   log are still outstanding; only after those may the gated workflow be run
   live. This phase performed **no** live VLAN validation.
5. **Why it stays disabled.** Creating a tagged child on a port that carries
   traffic can disturb frames on the parent; misclassifying one busy port as
   idle is enough to sever data access. The guard must be provably refusing
   non-idle ports against real hardware before the workflow may run live.
