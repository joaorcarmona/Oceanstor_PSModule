# HyperMetro Pairs

## Scope

LUN-level HyperMetro active-active pairs: create, modify, synchronize,
suspend, force start, and preferred-site priority switch. REST resource:
`HyperMetroPair`.

## Cmdlets

| Cmdlet | REST operation | Kind |
|---|---|---|
| `Get-DMHyperMetroPair` | `GET HyperMetroPair` / `GET HyperMetroPair/${id}` | Read-only |
| `New-DMHyperMetroPair` | `POST HyperMetroPair` | Mutating (creates DR relationship) |
| `Set-DMHyperMetroPair` | `PUT HyperMetroPair/${id}` | Mutating |
| `Remove-DMHyperMetroPair` | `DELETE HyperMetroPair/${id}` | Mutating (destroys DR relationship) |
| `Sync-DMHyperMetroPair` | `PUT HyperMetroPair/synchronize_hcpair` | Mutating (starts mirroring) |
| `Suspend-DMHyperMetroPair` | `PUT HyperMetroPair/disable_hcpair` | Mutating (pauses mirroring) |
| `Start-DMHyperMetroPair` | `PUT HyperMetroPair/startup_node` | **Force start: overrides arbitration** |
| `Switch-DMHyperMetroPairPriority` | `PUT HyperMetroPair/SWAP_HCPAIR` | **Priority-class: swaps preferred site** |

All mutating cmdlets accept `-Id` or `-Name` with `-WhatIf`/`-Confirm` and
`ConfirmImpact = 'High'`. Key `New-DMHyperMetroPair` parameters:
`-DomainId`/`-DomainName`, `-LocalLunId`/`-LocalLunName`,
`-RemoteLunId`/`-RemoteLunName`, `-RemoteDeviceId`, `-FirstSync`,
`-RecoveryPolicy`, `-Speed`, `-IsolationThresholdTime`, and `-ApiProperties`.
`Suspend-DMHyperMetroPair` accepts `-IsPrimary` to select which side is
suspended.

## Common Workflows

```text
Get-DMHyperMetroDomain              # confirm the target domain
Get-DMRemoteLun -RemoteServiceType HyperMetroSecondaryLun
New-DMHyperMetroPair                # create in a domain
Sync-DMHyperMetroPair               # initial/forced synchronization
Suspend-DMHyperMetroPair            # planned pause (maintenance)
Start-DMHyperMetroPair              # force start after outage (see safety)
Switch-DMHyperMetroPairPriority     # change preferred site (see safety)
Remove-DMHyperMetroPair             # tear down
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -PassThru -Credential $cred

# Read-only inventory with domain, link, and running status
Get-DMHyperMetroPair

# Create a pair in an existing domain by name
New-DMHyperMetroPair -DomainName 'metro-domain-01' `
    -LocalLunName 'app-lun-01' -RemoteLunName 'app-lun-01-m' -RemoteDeviceId '0'

# Always preview state changes
Suspend-DMHyperMetroPair -Name 'app-lun-01' -WhatIf
```

## Safety Notes

- `Start-DMHyperMetroPair` (force start) tells one array to serve I/O without
  quorum agreement. Using it on the wrong side of a real split-brain causes
  data divergence. Never run it outside a controlled recovery procedure.
- `Switch-DMHyperMetroPairPriority` changes which site wins arbitration — a
  production-placement decision. The integration harness gates it behind
  `HyperMetro.AllowPrioritySwitch`.
- `Suspend` stops active-active mirroring; hosts keep running on the remaining
  side only.

## Integrity Test Coverage

- Unit: `Tests/Unit/Public/replication-hypermetro-pair-lifecycle.Tests.ps1`
  covers create-body resolution (domain, local/remote LUN names), modify,
  sync/suspend/start/swap endpoints, and delete flags.
- Live: `Tests/Integration/Private/Workflows/HyperMetro.ps1` runs an opt-in
  test-owned pair lifecycle against a configured existing domain when
  `HyperMetro.Enabled` and `HyperMetro.AllowDrMutation` are set. Priority
  switch is `SkippedUnsafe` unless `HyperMetro.AllowPrioritySwitch` is set.

## Known Gaps

- Batch endpoints (`HyperMetroPair/batch`, `synchronize_hcpair/batch`,
  `disable_hcpair/batch`) are not wrapped.
- The dedicated preferred-policy modification endpoint is reachable only via
  `-ApiProperties` on `Set-DMHyperMetroPair`.
- No live force-start validation (requires a disposable lab pair and a
  controlled outage scenario).

## Related Files

- `POSH-Oceanstor/Public/*DMHyperMetroPair*.ps1`
- `POSH-Oceanstor/Private/class-OceanstorHyperMetroPair.ps1`
- `POSH-Oceanstor/Private/Resolve-DMDrPairHelper.ps1`
- `POSH-Oceanstor/Format/OceanstorHyperMetroPair.format.ps1xml`
