# Storage Pools

## Scope

Storage pool inventory, disk lookup, and pool **rename**. The module does not
implement storage pool creation, deletion, resize, or non-name updates
(description / thresholds / container config).

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMstoragePool` | List pools or filter by name | Read | Safe inventory |
| `Get-DMDiskByStoragePool` | Legacy wrapper to list disks by pool object, name, or ID | Read | Safe inventory |
| `Get-DMStoragePoolPerformance` | Realtime pool performance wrapper | Read | Safe when performance collection is expected |
| `Rename-DMstoragePool` | Rename a pool by name or ID (NAME label only) | Mutate | High-impact, `ConfirmImpact='High'`; fully reversible |

## Common Workflows

1. List pools before selecting placement for a LUN or file system.
2. Confirm pool disks when troubleshooting capacity or backend health.
3. Use performance wrappers for realtime triage, not provisioning.

## Examples

```powershell
Get-DMstoragePool -WebSession $storage
Get-DMstoragePool -WebSession $storage -Name 'Pool_01'
Get-DMstoragePool -WebSession $storage -Name 'Pool_01' | Get-DMDiskByStoragePool

# Rename a pool (preview first with -WhatIf; prompts because it is high-impact).
# Select the pool by name, by ID, or straight from the pipeline.
Rename-DMstoragePool -WebSession $storage -StoragePoolName 'Pool_01' -NewName 'Pool_01_archive' -WhatIf
Rename-DMstoragePool -WebSession $storage -StoragePoolId '0' -NewName 'Pool_01_archive'
Get-DMstoragePool -WebSession $storage -Name 'Pool_01' | Rename-DMstoragePool -NewName 'Pool_01_archive'
```

## Safety Notes

The inventory and disk-lookup cmdlets are read-only. Passing a pool ID to
`New-DMLun` or `New-DMFileSystem` is a separate mutating action and should be
reviewed.

`Rename-DMstoragePool` is the module's only storage-pool mutation. It changes
only the pool's `NAME` label via `PUT storagepool/{id}`; capacity, tiers,
thresholds, container configuration, and every LUN/file-system placement on the
pool are untouched, so a rename is fully reversible by renaming back. Because a
pool is shared infrastructure it is `ConfirmImpact='High'` and prompts by
default. Creating, deleting, resizing, or changing a pool's
description/threshold/container fields is intentionally not implemented.

## Integrity Test Coverage

Read-only integrity validates `Get-DMstoragePool` and disk lookup by pool when
sample data is available. Unit tests cover `Get-DMDiskByStoragePool`,
`Get-DMStoragePoolPerformance`, and `Rename-DMstoragePool` (mock-only). Mutating
integrity covers `Rename-DMstoragePool` as a **reversible rename round-trip** on
a pre-existing pool — read current name, rename to a run-unique temporary name,
read back, rename to the original name, verify restoration — gated behind
`-RunMutatingTests`, `AllowMutatingTests`, and `StoragePool.Enabled` +
`StoragePool.PoolName` (the exact pool to rename-and-restore). A cleanup action
restores the original name if the run aborts mid-round-trip.

## Known Gaps

- **Rename is implemented; `Set` / create / delete / resize are not.**
  `Rename-DMstoragePool` changes only the `NAME` label and is fully reversible.
  Changing a pool's `DESCRIPTION` / threshold / container fields (a `Set`
  command) and pool create/delete/resize remain **deferred/blocked** (high blast
  radius; `PUT storagepool/{id}` documented for Dorado 6.1.6 only, per-generation
  V3/V6 behavior unconfirmed). Any future accepted `Set` scope stays limited to
  explicitly-documented fields, with `SupportsShouldProcess`,
  `ConfirmImpact='High'`, mock-only tests, and a reversible or `SkippedUnsafe`
  live posture. Authoritative decision: `Oceanstor_PSModule_TODO.md` (Command
  Coverage Decisions).
- Capacity planning examples are intentionally limited to inventory and
  performance reads.

## Related Files

- `POSH-Oceanstor/Public/Get-DMstoragePool.ps1`
- `POSH-Oceanstor/Public/Get-DMDiskByStoragePool.ps1`
- `POSH-Oceanstor/Public/Get-DMStoragePoolPerformance.ps1`
- `POSH-Oceanstor/Public/Rename-DMstoragePool.ps1`
- `Tests/Unit/Public/Get-DMDiskByStoragePool.Tests.ps1`
- `Tests/Unit/Public/Rename-DMstoragePool.Tests.ps1`
- `Tests/Integration/Private/Workflows/StoragePool.ps1`
