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

## Standing read-only DR validation (Phase 07)

Every read-only live run now exercises the full DR getter surface via
`Tests/Integration/Private/ReadValidation.ps1`:

- `Get-DMRemoteDevice`, `Get-DMReplicationPair`,
  `Get-DMReplicationConsistencyGroup`, `Get-DMHyperMetroDomain`,
  `Get-DMHyperMetroPair`, `Get-DMHyperMetroConsistencyGroup`,
  `Get-DMVStorePair`, `Get-DMFileHyperMetroDomain`, and `Get-DMQuorumServer`
  are registered as read-only checks. All tolerate an empty result and are
  reported `NoData` rather than a failure on arrays with no DR configured.
- **`Get-DMRemoteLun` is guarded.** The REST collection requires a remote
  device id, so the check only runs when a replication-type remote device
  exists. When no remote devices exist — or none are replication-type — it is
  reported `NotConfigured`, never `Failed`. This keeps arrays without a remote
  configuration green.

`Get-DMQuorumServer` (new in Phase 07) is a read-only inventory getter over the
documented `QuorumServer` collection (REST §4.9.8). Use it to resolve a
`-QuorumServerId` for `Add-DMQuorumServerToHyperMetroDomain` without the
DeviceManager UI.

## `-WhatIf` coverage

All 52 DR mutators have systematic no-API-call-under-`-WhatIf` coverage in
`Tests/Unit/Public/replication-hypermetro-whatif.Tests.ps1`, driven by the
shared `Tests/Unit/Support/Assert-DMWhatIfSafe.ps1` helper from a single
`-ForEach` case table. The same spec asserts `ConfirmImpact = 'High'` on every
in-place modify / remove / lifecycle-transition cmdlet (create cmdlets use the
default impact). This proves `-WhatIf` sends no mutating request body and that
`ShouldProcess` gates every mutation.

## Enum / status translation audit

DR classes translate the operational status enums that operators read, keeping
the raw code alongside as an `X Code` companion property. Verified against the
OceanStor Dorado 6.1.6 REST enum tables:

- **Translated (confirmed):** health status, running status, link status,
  domain type (SAN/NAS), arbitration/quorum type, replication type
  (Sync/Async), array type, and quorum running status (27 online / 28 offline).
  Unmapped codes fall through to the raw value rather than being guessed.
- **Intentionally left raw (round-trip fidelity):** `Speed`, `Recovery Policy`,
  `Replication Mode`, `Synchronization Type`, and `Is Primary` on the pair
  classes surface the exact REST codes that the matching `New-*`/`Set-*`
  parameters accept and emit (e.g. `Speed` 1–4 = Low/Medium/High/Highest per
  the cmdlet `ValidateSet`). Translating them would make the getter output
  asymmetric with the setter input in the most safety-sensitive domain, so
  they remain raw by design.
- **Deliberate label choice:** HyperMetro consistency-group running status `41`
  is surfaced as `Suspended` to match the `Suspend-DM*` verb that produces it;
  the REST reference labels the same code `Paused`. This is a naming choice,
  not a translation error, and is kept for verb/output consistency.

Rule going forward: only translate a code when the 6.1.6 reference confirms its
meaning; a wrong translation in the DR domain is worse than a raw code.

## Lab-pair mutation runbook

Human-supervised procedure for a gated DR mutation validation run. Never run
unattended; never point it at pre-existing DR objects.

### Prerequisites (operator supplies, then reviews)

1. **Remote array reachable** and a **remote device already configured** on the
   local array (`Get-DMRemoteDevice` returns it). The harness never creates or
   mutates remote devices.
2. **DR-capable storage pool** on the local array for the test-owned LUN
   (`StoragePoolId` in the config; the pool is never modified).
3. **Remote LUN** on the remote device intended for this run
   (`Get-DMRemoteLun -RemoteDeviceId <id>` or `Get-DMQuorumServer` /
   `Get-DMHyperMetroDomain` for the HyperMetro path). For HyperMetro, an
   **existing SAN domain** the harness will consume read-only.
4. A **unique `NamePrefix`** so every created object is identifiable and
   cleanup can never match a pre-existing object.

### Required config flags

```powershell
# Replication path
Replication = @{
    Enabled         = $true
    AllowDrMutation = $true        # acknowledges lab DR mutation
    AllowFailover   = $false       # keep OFF unless doing a supervised switchover
    RemoteDeviceId  = '<lab remote device id>'
    RemoteLunId     = '<lab remote lun id>'   # or RemoteLunName
}

# HyperMetro path
HyperMetro = @{
    Enabled             = $true
    AllowDrMutation     = $true
    AllowPrioritySwitch = $false   # keep OFF unless doing a supervised priority switch
    RemoteDeviceId      = '<lab remote device id>'
    RemoteLunId         = '<lab remote lun id>'
    DomainId            = '<existing SAN domain id>'  # consumed read-only
}
```

### Expected outcomes

- Test-owned local LUN created, replication/HyperMetro pair created against the
  configured remote LUN, ID registered for cleanup **immediately**.
- Safe lifecycle only: sync/split (replication) or sync/suspend/re-sync
  (HyperMetro) on the **test-owned** pair, plus a test-owned consistency-group
  associate/disassociate.
- **`SkippedUnsafe`** (by design, unless the dedicated flag is set):
  `Switch-*` switchover, `Switch-DMHyperMetroPairPriority`,
  `Start-DMHyperMetroPair`/force-start, and any secondary-access change against
  a non-test-owned object.
- **Never touched:** pre-existing pairs/groups/domains/quorum, remote devices,
  vStore pairs, and file-system DR objects. Domain and quorum objects are
  consumed read-only.
- Cleanup deletes the pair and group **by captured ID** in a `finally` block.
  On cleanup failure the harness prints the type, ID, and name; remove manually
  by ID after confirming the `NamePrefix`.

### Rollback / supervision

- The workflow is create → verify → safe-lifecycle → delete, entirely on
  run-owned objects, so a clean run leaves the array as it started.
- If any step fails mid-run, stop and reconcile by captured ID before retrying;
  do not broaden the config to "fix" a failure.
- An operator must review the intended config (remote IDs, prefix, flags)
  before every run.

### Example command (public — credentials redacted)

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP -Credential $cred -SkipCertificateCheck `
    -RunMutatingTests -ShowTestExecution
```

Internal lab note: the ready DR lab is `StorageIP` and requires
`-SkipCertificateCheck`; the credential is imported from
`$env:USERPROFILE\.oceanstor\dm-creds.xml`. Never inline or print the
credential. The DR sections in `IntegrityValidationConfig.psd1` must be enabled
and populated with the lab remote IDs (above) before `-RunMutatingTests` runs
any DR workflow; they ship disabled and default runs remain read-only.
