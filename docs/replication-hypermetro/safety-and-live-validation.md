# Safety and Live Validation

Replication and HyperMetro cmdlets manipulate disaster-recovery state:
replication direction, site priority, secondary access, split/sync state, and
which array serves production data. This page defines what is safe to run
live, what is gated, and how the integration harness enforces it.

## Risk classes

| Class | Examples | Live rule |
|---|---|---|
| Read-only inventory/status | All `Get-*` cmdlets in this area | Safe to run live, including production |
| Test-owned create/delete | `New-/Remove-DMReplicationPair`, `New-/Remove-DMHyperMetroPair`, group create/delete | Only on lab arrays, only on resources created by the same run, config-gated |
| Replication state | `Sync-/Split-DMReplicationPair`, group sync/split | Disabled by default; test-owned resources only |
| HyperMetro state | `Sync-/Suspend-DMHyperMetroPair`, group sync/stop | Disabled by default; test-owned resources only |
| Force start | `Start-DMHyperMetroPair`, `Start-DMHyperMetroConsistencyGroup` | Overrides arbitration — never run casually; not exercised by the harness |
| Failover / switchover | `Switch-DMReplicationPair`, `Switch-DMReplicationConsistencyGroup`, `Switch-DMVStorePair`, `Switch-DMFileHyperMetroDomain` | Requires explicit failover opt-in |
| Priority / role switch | `Switch-DMHyperMetroPairPriority`, `Switch-DMHyperMetroConsistencyGroup` | Requires explicit priority-switch opt-in |
| Secondary access | `Enable-/Disable-DMReplicationPairSecondaryProtection`, file-system write-lock/read-only cmdlets | Disabled by default; test-owned resources only |
| Domain / quorum | `New-/Set-/Remove-DMHyperMetroDomain`, quorum add/remove | Disabled by default; harness consumes an existing configured domain and never mutates domains |
| NAS / vStore DR | vStore pair and file HyperMetro mutations | Disabled by default; extra service-impact caution — tenant-wide blast radius |

Every mutating cmdlet supports `-WhatIf`/`-Confirm` and declares
`ConfirmImpact = 'High'`, so `-Confirm` prompts appear at default preference
settings. Preview first:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

Sync-DMReplicationPair -Name 'app-lun-01' -WhatIf
```

## Non-negotiable rules

- Never modify, delete, split, sync, switch, suspend, start, or change
  priority on **pre-existing** replication pairs, consistency groups,
  HyperMetro pairs/groups/domains, quorum associations, vStore pairs, or
  file-system DR objects. Existing DR configuration is read-only.
- Only objects created by the current validation run may be mutated or
  deleted.
- Cleanup deletes by captured ID, registered immediately after creation —
  never by name matching, never broadly.
- Failover, switchover, and priority-switch operations change which site
  serves production-like data. They require their own opt-in flags on top of
  the general mutation opt-in.

## Integration harness gating

The live harness (`Tests/Integration/Invoke-GetterIntegrityValidation.ps1`)
reads `Tests/Integration/IntegrityValidationConfig.psd1`. Both DR sections
ship disabled:

```powershell
Replication = @{
    Enabled = $false          # master switch for the replication workflow
    AllowDrMutation = $false  # must also be true for any DR mutation
    AllowFailover = $false    # additionally gates Switch-* switchover
    RemoteDeviceId = ''       # or RemoteDeviceName
    RemoteLunId = ''          # or RemoteLunName
    RemoteServiceType = 'ReplicationSecondaryLun'
}

HyperMetro = @{
    Enabled = $false
    AllowDrMutation = $false
    AllowPrioritySwitch = $false  # additionally gates priority switches
    RemoteDeviceId = ''
    RemoteLunId = ''
    RemoteServiceType = 'HyperMetroSecondaryLun'
    DomainId = ''             # existing SAN domain; the harness never creates
    DomainName = ''           # or deletes domains
}
```

With the sections disabled, all DR commands are reported as `NotConfigured`.
With mutation enabled but the failover/priority flags off, switchover and
priority-switch commands are reported as `SkippedUnsafe` — deliberately not
counted as passed.

The workflows:

1. Preflight remote device, remote LUN, and (HyperMetro) domain visibility.
2. Create a pair from the run's test-owned local LUN and the configured
   remote LUN.
3. Register the created ID for cleanup immediately.
4. Read back, then exercise safe lifecycle operations (sync/split or
   sync/suspend/re-sync).
5. Create a test-owned consistency group, associate/disassociate the pair,
   and delete the group.
6. Delete the pair by captured ID in cleanup.

## Recommended staged validation order

1. Unit suite (`./Tests/Invoke-UnitTests.ps1`) — no array required.
2. Read-only live validation against any array — getters only.
3. Test-owned SAN replication workflow on a lab pair
   (`Replication.Enabled + AllowDrMutation`).
4. Test-owned HyperMetro workflow on a lab pair with an existing domain
   (`HyperMetro.Enabled + AllowDrMutation`).
5. Failover/priority-switch coverage only in a dedicated DR exercise window
   (`AllowFailover` / `AllowPrioritySwitch`).
6. NAS/vStore DR flows manually, with tenant-level change control (no
   harness coverage yet).

If cleanup ever fails, the harness reports the object type, ID, and name;
remove the object manually by ID (for example
`Remove-DMReplicationPair -Id '<captured-id>'`) after confirming it carries
the run's `NamePrefix`.
