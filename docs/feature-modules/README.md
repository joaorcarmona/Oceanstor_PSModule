# Feature Modules

POSH-Oceanstor groups its ~314 public commands into named **features**. A feature
is a set of related commands that can be enabled or disabled as a unit. Disabling a
feature hides its commands entirely — they are not exported, so `Get-Command`,
tab-completion, and `Import-Module` do not surface them until the feature is
re-enabled.

The feature map is the single source of truth for which command belongs to which
feature: [`POSH-Oceanstor/DMFeatureMap.psd1`](../../POSH-Oceanstor/DMFeatureMap.psd1).
Every exported command is assigned to exactly one feature, and a Pester suite fails
CI if that invariant is ever broken.

> **Production-readiness warning.** Two features — **HyperMetro** and
> **Replication** — ship **disabled by default because they are still in
> development and are not yet fully validated.** Their live-mutation paths cannot
> be exercised by the automated integrity harness without a second array and a
> quorum server, so they have **not** been proven against real disaster-recovery
> hardware end to end. **Treat these features as experimental and do not rely on
> them in production** until they are promoted to default-enabled in a future
> release. Everything else ships enabled and is covered by the normal test and
> live-validation process.

## Feature taxonomy

| Feature | Default | Status | Contents |
|---|---|---|---|
| `Core` | always on (locked) | Stable | Connect/Disconnect, `Get-DMSystem`, exports, and the `*-DMFeature` cmdlets |
| `HyperMetro` | **off** | **In development — not production ready** | HyperMetro domains/pairs/consistency-groups and quorum servers |
| `Replication` | **off** | **In development — not production ready** | Remote replication pairs/consistency-groups, vStore pairs, remote device/LUN |
| `Host` | on | Stable | Hosts, host groups, FC/iSCSI/NVMe initiators, host links |
| `Lun` | on | Stable | LUN CRUD, LUN groups, workload types |
| `Mapping` | on | Stable | Mapping views, port groups, map/unmap commands |
| `Snapshot` | on | Stable | LUN snapshots, snapshot consistency groups, HyperCDP schedules |
| `Protection` | on | Stable | Protection groups |
| `QoS` | on | Stable | QoS policies and associations |
| `FileSystem` | on | Stable | File systems, FS snapshots, dTrees, quotas, CIFS/NFS shares & clients, vStores |
| `Network` | on | Stable | ETH/FC/SAS ports, VLANs, LIFs, bonds, failover groups, DNS, LLDP |
| `Hardware` | on | Stable | Disks, enclosures, controllers, BBUs, interface modules, equipment status |
| `StoragePool` | on | Stable | Storage pool getters and rename |
| `Performance` | on | Stable | Performance counters, capacity history, monitoring, report tasks |
| `SystemManagement` | on | Stable | Alarms, certificates, local users, roles, SNMP, NTP, syslog, timezone/UTC |

`Core` is **locked**: it can never be disabled, and any attempt to disable it fails
with a terminating error.

## Why HyperMetro and Replication are off by default

These two features drive multi-array disaster-recovery workflows — replication
direction, site priority, secondary-access state, split/sync, and which array
serves production data. Validating them safely requires a *paired* array (and, for
HyperMetro, a quorum server) that most environments — and the module's own CI —
do not have. Until that end-to-end validation is in place:

- The commands are **hidden by default** so they cannot be invoked accidentally.
- They are considered **experimental / not production ready**.
- Enabling them is an explicit, opt-in action recorded in your user config.

When you do enable them, read the domain safety guide first:
[docs/replication-hypermetro/safety-and-live-validation.md](../replication-hypermetro/safety-and-live-validation.md).
The command-level documentation lives in
[docs/replication-hypermetro/](../replication-hypermetro/README.md).

## Listing features

```powershell
# Show every feature, its configured state, and how many commands it groups.
Get-DMFeature

# Inspect specific features.
Get-DMFeature -Name HyperMetro, Replication
```

`Get-DMFeature` returns one object per feature:

| Property | Meaning |
|---|---|
| `Name` | Feature name. |
| `Enabled` | The **configured** state — what a fresh import would use. |
| `ActiveInSession` | The state captured when the current session last imported the module. Differs from `Enabled` after a toggle until you re-import. |
| `DefaultEnabled` | The built-in default, ignoring any user override. |
| `Source` | `Default` (built-in) or `UserConfig` (overridden in the config file). |
| `CommandCount` | Number of commands in the feature. |
| `Description` | Human-readable summary. |

## Enabling and disabling features

```powershell
# Enable HyperMetro, then re-import so its commands become available in THIS session.
Enable-DMFeature -Name HyperMetro
Import-Module POSH-Oceanstor -Force

# Disable it again (removes the override and hides the commands on next import).
Disable-DMFeature -Name HyperMetro
Import-Module POSH-Oceanstor -Force
```

Key behaviours:

- **A toggle does not affect the current session.** Export lists are fixed at
  import time. You must run `Import-Module POSH-Oceanstor -Force`, or start a new
  session, for the change to take effect. Both toggle cmdlets emit a warning
  reminding you of this.
- `Enable-DMFeature` / `Disable-DMFeature` support `-WhatIf` and `-Confirm`.
- Disabling `Core`, or naming a feature that does not exist, is a terminating
  error.

## Configuration file

Overrides are stored per-user as JSON at:

```text
%APPDATA%\POSH-Oceanstor\ModuleConfig.json
```

- **Only overrides that differ from the built-in default are written.** Toggling a
  feature back to its default removes its key, so the file stays minimal (an empty
  `{}` means "all defaults").
- The directory is created on first write.
- Set the environment variable `POSH_OCEANSTOR_CONFIG_PATH` to redirect the file
  to another location — used by labs and CI so tests never touch the real user
  profile:

  ```powershell
  $env:POSH_OCEANSTOR_CONFIG_PATH = 'C:\lab\dm-feature-config.json'
  ```

Example file after enabling HyperMetro:

```json
{
  "HyperMetro": true
}
```

## Fail-open guarantee

Feature resolution can **never** stop the module from importing:

- **Missing config file** → built-in defaults, no warning.
- **Malformed / unreadable JSON** → warn and fall back to defaults for every
  feature.
- **Unknown feature names in the config** → warn and ignore those keys.
- **A command that is not mapped to any feature** → fails open (stays exported);
  the FeatureMap Pester suite catches the mapping gap at CI time rather than
  hiding a command silently.

## How it works internally

- [`POSH-Oceanstor/DMFeatureMap.psd1`](../../POSH-Oceanstor/DMFeatureMap.psd1) —
  the feature → command map (with `DefaultEnabled`, `Locked`, `Description`).
- `Private/Get-DMFeatureConfigPath.ps1` — resolves the config path (honours
  `POSH_OCEANSTOR_CONFIG_PATH`).
- `Private/Get-DMFeatureState.ps1` — layers the user overrides on top of the map
  and returns the effective state; the fail-open resolver used both at import and
  by `Get-DMFeature`.
- `Private/Set-DMFeatureConfig.ps1` — shared writer behind the toggle cmdlets;
  prunes redundant and locked keys before persisting.
- `POSH-Oceanstor.psm1` — after dot-sourcing all commands, filters
  `Export-ModuleMember` against the effective state and exports only the aliases
  whose target command is itself exported.

Because the live getter-integrity harness dot-sources every public file directly
(bypassing `Export-ModuleMember`), disabling a feature does **not** affect lab
validation of HyperMetro/Replication — those workflows keep working unchanged when
run through the harness.

## Testing

| Suite | Covers |
|---|---|
| [`Tests/Unit/Private/FeatureMap.Tests.ps1`](../../Tests/Unit/Private/FeatureMap.Tests.ps1) | Every export is in exactly one feature; no duplicates; HyperMetro/Replication default off, all others on; Core locked. |
| [`Tests/Unit/Public/Feature-Commands.Tests.ps1`](../../Tests/Unit/Public/Feature-Commands.Tests.ps1) | `Get`/`Enable`/`Disable-DMFeature` behaviour, config writes/pruning, unknown-name and locked-Core errors, malformed/unknown-key config fallback. |
| [`Tests/Unit/ModuleImport.Feature.Tests.ps1`](../../Tests/Unit/ModuleImport.Feature.Tests.ps1) | Real `Import-Module` round-trip in a child process: disabled commands hidden, enabled commands present, no dangling aliases. |
