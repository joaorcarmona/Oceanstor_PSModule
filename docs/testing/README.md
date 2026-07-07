# Testing Guide — POSH-Oceanstor

This is the landing page for all testing documentation. It links out to focused
guides and gives you the fastest path to the right test command.

## When to use each test type

| You want to... | Use |
|---|---|
| Validate logic offline, no array needed | [Unit tests](UNIT-TESTS.md) |
| Confirm getters work against a real array, read-only | [Integrity tests](integrity-tests.md) (default mode) |
| Exercise create/update/delete workflows the harness owns and cleans up | [Integrity tests](integrity-tests.md) (`-RunMutatingTests`) |
| Validate realtime/Excel/history/capacity performance cmdlets | [Performance integrity tests](performance-integrity-tests.md) |
| Understand the `Tests/` folder layout and status vocabulary | [Test schema & organization](test-schema-organization.md) |
| Understand what is and isn't safe to run against a live array | [Live validation safety](live-validation-safety.md) |

## Recommended command order

1. Static checks: `git diff --check`
2. Unit tests (offline, no credentials): `./Tests/Invoke-UnitTests.ps1`
3. Read-only getter integrity (live, read-only): `Invoke-GetterIntegrityValidation.ps1` with no extra switches
4. Realtime performance integrity: add `-IncludePerformance`
5. Excel performance integrity: add `-IncludeExcelPerformance`
6. Performance history / capacity: add `-IncludePerformanceHistory` / `-IncludeCapacityHistory` (requires `Performance.AllowReportTaskCreation = $true`)
7. Mutating integrity: `-RunMutatingTests` (requires `AllowMutatingTests = $true` in config)
8. Monitoring mutation (rarely needed): `-AllowMonitoringMutation` (requires `Performance.AllowMonitoringMutation = $true` in config)

Run each stage on its own before combining switches — every stage above is
independent and opt-in; nothing you don't ask for runs.

## Safety model summary

- **Unit tests** never touch a live array.
- **Read-only integrity** (no switches) only calls `Get-*`/list cmdlets.
- **Mutating integrity** (`-RunMutatingTests`) only touches resources it creates
  itself this run — every write is registered as test-owned before use, and
  cleanup deletes only by that captured identity.
- **Performance integrity** is opt-in per stage and double-gated: a runner
  switch (`-IncludePerformance`, `-IncludePerformanceHistory`,
  `-IncludeCapacityHistory`, `-IncludeExcelPerformance`) *and* the matching
  `Performance.*` flag in `IntegrityValidationConfig.psd1` must both be set.
  Without a switch, the performance section returns immediately and nothing
  it can do is attempted — see
  [Why performance commands may appear as NotRequested](performance-integrity-tests.md#why-performance-commands-may-appear-as-notrequested-or-previously-blocked).
- **Monitoring mutation** (sampling-interval round-trip) is gated a second
  time on top of the performance gate and always restores the original value
  in a `finally` block.

## Quick matrix of domains and switches

| Test Domain | Purpose | Main Command/Switch | Requires Live Array | Can Mutate Array | Config Gate |
|---|---|---|---:|---:|---|
| Unit tests | Offline validation | `./Tests/Invoke-UnitTests.ps1` | No | No | No |
| Getter integrity | Live read/getter validation | `Invoke-GetterIntegrityValidation.ps1` (no switch) | Yes | No | No |
| Mutating integrity | Test-owned mutation workflows | `-RunMutatingTests` | Yes | Yes, test-owned only | `AllowMutatingTests` |
| Realtime performance integrity | Realtime performance validation | `-IncludePerformance` | Yes | No | `Performance.Enabled` |
| Excel performance integrity | Excel performance export validation | `-IncludePerformance -IncludeExcelPerformance` | Yes | Local file only | `Performance.Enabled` |
| Performance history | Report-task performance history | `-IncludePerformanceHistory` | Yes | Test-owned report tasks | `Performance.Enabled` + `AllowReportTaskCreation` |
| Capacity history | Capacity report-task validation | `-IncludeCapacityHistory` | Yes | Test-owned report tasks | `Performance.Enabled` + `AllowReportTaskCreation` |
| Monitoring mutation | Sampling interval round-trip | `-IncludePerformance -AllowMonitoringMutation` | Yes | Yes, monitoring setting only | `Performance.Enabled` + `AllowMonitoringMutation` |

## Storage Domain Coverage

| Public docs | Read-only integrity | Mutating integrity | Main config gates |
|---|---|---|---|
| [Block storage](../block-storage/README.md) | LUNs, storage pools, hosts, host groups, LUN groups, mapping views, initiators, protection groups | Test-owned LUN, LUN group, host, host group, initiator, mapping, direct mapping, protection, HyperCDP schedule | `Lun`, `LunGroup`, `Host`, `Initiators`, `Mapping`, `Protection`, `HyperCDPSchedule` |
| [File storage](../file-storage/README.md) | File systems, NFS/CIFS shares, NFS clients, file-system snapshots, quotas | Test-owned file system, dTree, NFS, CIFS, file-system snapshot, quota | `Nas` and `Nas.Enable*` flags |
| [QoS](../qos/README.md) | SmartQoS policy inventory | Test-owned SmartQoS policy, enable/disable, update, LUN/LUN-group association | `QoS`, plus `Lun` and `LunGroup` |
| [Snapshots](../snapshots/README.md) | LUN snapshots, file-system snapshots, snapshot consistency groups, HyperCDP schedules | Test-owned LUN snapshots, file-system snapshots, snapshot consistency groups, snapshot copies, HyperCDP schedules | `Lun`, `Nas.EnableFileSystemSnapshot`, `Protection`, `HyperCDPSchedule` |

Destructive storage operations are skipped unless the workflow created the
resource in the same run, registered it as test-owned, and can clean it up by
captured identity. Do not treat `SkippedUnsafe` as a failure; it means the
harness intentionally avoided an unsafe live action.

## Recommended offline validation

```powershell
git diff --check
./Tests/Invoke-UnitTests.ps1
```

## Recommended safe live getter validation

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck
```

## Recommended realtime performance validation

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

.\Tests\Integration\Invoke-GetterIntegrityValidation.ps1 `
    -Hostname $storageIP `
    -Credential $cred `
    -SkipCertificateCheck `
    -IncludePerformance
```

This requires `Performance.Enabled = $true` in
`Tests/Integration/IntegrityValidationConfig.psd1`; otherwise the run emits a
single `Performance validation | NotConfigured` check and stops there.

## See also

- [Unit tests](UNIT-TESTS.md)
- [Integrity tests](integrity-tests.md)
- [Performance integrity tests](performance-integrity-tests.md)
- [Test schema & organization](test-schema-organization.md)
- [Live validation safety](live-validation-safety.md)
