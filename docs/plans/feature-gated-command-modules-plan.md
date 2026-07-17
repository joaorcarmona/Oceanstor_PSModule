# Feature-gated command groups for POSH-Oceanstor

## Context

Some command domains (HyperMetro, Replication) cannot be live-validated by the integrity harness — they require a second array / quorum setup that production environments don't expose to the harness. The user wants these commands **hidden by default in production**, organized as named features ("module HyperMetro", "module Replication", "module FileSystem", "module Network", …) that can be enabled/disabled through a global module config.

Decisions confirmed with the user:
- **Default-disabled**: `HyperMetro` and `Replication` only; everything else enabled by default (but individually disableable).
- **Mechanism**: hidden at import — disabled features' commands are simply not exported (`Get-Command`/tab-completion don't see them). Toggling requires `Import-Module -Force`; the toggle cmdlets warn about this.
- **Config**: per-user JSON at `%APPDATA%\POSH-Oceanstor\ModuleConfig.json` (stores only explicit overrides; missing file/keys = built-in defaults).
- **Control cmdlets**: `Get-DMFeature`, `Enable-DMFeature`, `Disable-DMFeature`.

Key facts from exploration:
- All ~313 public functions are dot-sourced by [POSH-Oceanstor.psm1](POSH-Oceanstor/POSH-Oceanstor.psm1) and exported via `Export-ModuleMember -Function $Public.Basename -Alias *`; the manifest's explicit `FunctionsToExport` list acts as a ceiling (effective exports = intersection), so psm1-level filtering is sufficient and the manifest list stays complete.
- Aliases are declared per-file with `Set-Alias` (e.g. [Get-DMhost.ps1:279](POSH-Oceanstor/Public/Get-DMhost.ps1#L279)); alias export must be filtered to aliases whose target function is exported.
- No config mechanism exists today.
- The unit tests ([Tests/loadScripts.ps1](Tests/loadScripts.ps1)) and the integrity harness ([Invoke-GetterIntegrityValidation.ps1:77](Tests/Integration/Invoke-GetterIntegrityValidation.ps1#L77)) dot-source files into their own scope/dynamic module — **neither imports the real psm1**, so export filtering cannot break them.
- Inventory-enforcement pattern to reuse: [ModuleInventory.Tests.ps1](Tests/Unit/Private/ModuleInventory.Tests.ps1) + a psd1 data file (like [Tests/ModuleCoverage.psd1](Tests/ModuleCoverage.psd1)).
- Repo conventions: string-form `[OutputType('X')]`, PSScriptAnalyzer-clean, no BOM issues, new Private helpers must be added to the harness dot-source whitelist.

## Feature taxonomy

New data file `POSH-Oceanstor/DMFeatureMap.psd1` shipped with the module:

```powershell
@{
    Features = @{
        HyperMetro = @{
            DefaultEnabled = $false
            Description    = 'Block/file HyperMetro pairs, domains, consistency groups, quorum servers. Not live-validatable without a lab array pair.'
            Commands       = @('Get-DMHyperMetroPair', 'New-DMHyperMetroPair', ...)
        }
        Replication = @{ DefaultEnabled = $false; ... }
        FileSystem  = @{ DefaultEnabled = $true;  ... }
        ...
    }
}
```

Feature assignment (every one of the ~313 exported functions goes in **exactly one** feature; enforced by test):

| Feature | Default | Contents |
|---|---|---|
| `Core` | always on, cannot be disabled | `Connect-deviceManager`, `Disconnect-deviceManager`, `Get-DMSystem`, `Export-DeviceManager`, `Export-DMInventory`, `Export-DMStorageToExcel`, and the three new `*-DMFeature` cmdlets |
| `HyperMetro` | **off** | all `*HyperMetro*` (block + `*FileHyperMetroDomain*`), quorum server commands (`Get-DMQuorumServer`, `Add/Remove-DMQuorumServer*`) |
| `Replication` | **off** | all `*ReplicationPair*` / `*ReplicationConsistencyGroup*` (block + FileSystem variants), `*VStorePair*`, `Get-DMRemoteDevice`, `Get-DMRemoteLun` |
| `Host` | on | hosts, host groups, FC/iSCSI/NVMe initiators, host links |
| `Lun` | on | LUN CRUD, LUN groups, workload types |
| `Mapping` | on | mapping views, port groups, map/unmap commands |
| `Snapshot` | on | LUN snapshots, snapshot consistency groups, HyperCDP schedules |
| `Protection` | on | protection groups |
| `QoS` | on | QoS policies and associations |
| `FileSystem` | on | file systems, FS snapshots, dTrees, quotas, CIFS/NFS shares & clients, `Get-DMvStore` |
| `Network` | on | ETH/FC/SAS ports, VLANs, LIFs, bonds, failover groups, DNS, LLDP |
| `Hardware` | on | disks, enclosures, controllers, BBU, interface modules, equipment status |
| `StoragePool` | on | storage pool getters + rename |
| `Performance` | on | all performance/capacity/monitoring/report-task commands |
| `SystemManagement` | on | alarms, SNMP, syslog, NTP, local users, roles, certificates, timezone/UTC time |

(Exact per-command assignment happens during implementation, sorted from the manifest's `FunctionsToExport`; the completeness test makes drift impossible.)

## Implementation

### 1. Feature map + private helpers

- **New** `POSH-Oceanstor/DMFeatureMap.psd1` — taxonomy above.
- **New** `POSH-Oceanstor/Private/Get-DMFeatureConfigPath.ps1` — returns `Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'POSH-Oceanstor\ModuleConfig.json'`; honors `$env:POSH_OCEANSTOR_CONFIG_PATH` override (used by tests, and lets labs/CI point at a shared config).
- **New** `POSH-Oceanstor/Private/Get-DMFeatureState.ps1` — loads the map (`Import-PowerShellDataFile`) + user config JSON, returns one object per feature: `Name`, `Enabled` (effective), `DefaultEnabled`, `Source` (`Default`/`UserConfig`), `Description`, `Commands`. Malformed/unreadable JSON → warn and fall back to defaults (never block module import). Unknown feature names in the config → warn and ignore.
- Add the two new private helpers to the dot-source whitelist in `Invoke-GetterIntegrityValidation.ps1` (per repo convention).

### 2. psm1 export filtering

Edit [POSH-Oceanstor.psm1](POSH-Oceanstor/POSH-Oceanstor.psm1) — after dot-sourcing everything:

1. Call `Get-DMFeatureState`; store in `$script:DMFeatureState` (so `Get-DMFeature` can report what's active in the current session without re-reading disk).
2. Enabled commands = `Core` + commands of every enabled feature. Defensive: any exported file whose BaseName is missing from the map exports anyway (fail-open, the inventory test catches the gap at CI time).
3. `Export-ModuleMember -Function $enabledCommands -Alias $enabledAliases`, where `$enabledAliases = (Get-Alias | Where-Object { $_.Definition -in $enabledCommands }).Name` evaluated in module scope.
4. `Write-Verbose` one line listing disabled features.

### 3. New public cmdlets (always exported, in `Core`)

- **`Get-DMFeature [-Name <string[]>]`** — lists features with `Name`, `Enabled` (configured), `ActiveInSession` (from `$script:DMFeatureState` captured at import — differs from `Enabled` after a toggle until re-import), `DefaultEnabled`, `Source`, `CommandCount`, `Description`.
- **`Enable-DMFeature -Name <string[]>`** / **`Disable-DMFeature -Name <string[]>`** — `SupportsShouldProcess`; validate names against the map; `Disable-DMFeature -Name Core` → terminating error. Writes only overrides that differ from defaults into the JSON (removes redundant keys), creating the config directory on first write. Emits `Write-Warning 'Run Import-Module POSH-Oceanstor -Force (or start a new session) for the change to take effect.'` when the change alters the current session's state.
- String-form `[OutputType('...')]`, comment-based help, follow existing Public/*.ps1 file style.

### 4. Manifest

Add `Get-DMFeature`, `Enable-DMFeature`, `Disable-DMFeature` to `FunctionsToExport` in [POSH-Oceanstor.psd1](POSH-Oceanstor/POSH-Oceanstor.psd1). The existing full list stays — it's the ceiling; runtime hiding happens in psm1.

### 5. Tests

- **New** `Tests/Unit/Private/FeatureMap.Tests.ps1` (inventory-style, mirrors ModuleInventory.Tests.ps1):
  - every `FunctionsToExport` entry appears in exactly one feature's `Commands`;
  - every mapped command exists in `FunctionsToExport`;
  - `Core` contains the session + feature cmdlets; `HyperMetro`/`Replication` have `DefaultEnabled = $false`, all others `$true`.
- **New** `Tests/Unit/Public/Feature-Commands.Tests.ps1` — Get/Enable/Disable behavior against a temp config path via `$env:POSH_OCEANSTOR_CONFIG_PATH`: defaults with no file; enable HyperMetro → JSON contains only the override; disable it again → key removed; unknown name errors; `Disable-DMFeature Core` errors; malformed JSON falls back to defaults with a warning.
- **New** `Tests/Unit/ModuleImport.Feature.Tests.ps1` — real `Import-Module` round-trip in a **child `pwsh -NoProfile` process** (keeps the Pester session clean, avoids the known class/module-scope quirks): with no config, assert `Get-Command -Module POSH-Oceanstor` contains no `*HyperMetro*`/`*ReplicationPair*` commands but does contain `Get-DMhost` etc., and that aliases of hidden commands are absent; with a temp config enabling HyperMetro, assert those commands appear.

### 6. Docs

- README: new "Feature modules" section — taxonomy table, defaults, config file location, `Enable-DMFeature`/`Import-Module -Force` workflow.
- RELEASE_NOTES entry.

## Files touched (summary)

| File | Change |
|---|---|
| `POSH-Oceanstor/DMFeatureMap.psd1` | new — feature→command map |
| `POSH-Oceanstor/Private/Get-DMFeatureConfigPath.ps1` | new |
| `POSH-Oceanstor/Private/Get-DMFeatureState.ps1` | new |
| `POSH-Oceanstor/Public/Get-DMFeature.ps1`, `Enable-DMFeature.ps1`, `Disable-DMFeature.ps1` | new |
| `POSH-Oceanstor/POSH-Oceanstor.psm1` | export filtering |
| `POSH-Oceanstor/POSH-Oceanstor.psd1` | +3 FunctionsToExport |
| `Tests/Integration/Invoke-GetterIntegrityValidation.ps1` | +2 private-helper whitelist entries |
| `Tests/Unit/Private/FeatureMap.Tests.ps1`, `Tests/Unit/Public/Feature-Commands.Tests.ps1`, `Tests/Unit/ModuleImport.Feature.Tests.ps1` | new tests |
| `README.md`, `RELEASE_NOTES.md` | docs |

## Verification

1. `Invoke-Pester Tests/Unit/Private/FeatureMap.Tests.ps1, Tests/Unit/Public/Feature-Commands.Tests.ps1, Tests/Unit/ModuleImport.Feature.Tests.ps1` (via rtk).
2. Full unit suite + existing `ModuleInventory.Tests.ps1` still green.
3. `Invoke-ScriptAnalyzer` on new/changed files — zero findings.
4. Manual end-to-end in a fresh `pwsh`: `Import-Module .\POSH-Oceanstor` → `Get-DMFeature` shows HyperMetro/Replication disabled; `Get-Command Get-DMHyperMetroPair` fails; `Enable-DMFeature HyperMetro` + `Import-Module -Force` → command visible; `Disable-DMFeature HyperMetro` restores default and deletes the override key from the JSON.

## Risks / notes

- Toggling requires re-import — by design (chosen option); the cmdlets warn.
- Module auto-loading: a disabled command still appears in the manifest, so typing it triggers autoload and then fails with "not recognized" — acceptable and consistent with "hidden".
- The integrity harness and unit-test loader dot-source files directly, so gating never blocks validation runs — lab validation of Replication/HyperMetro keeps working unchanged.
- Fail-open on unmapped commands + config parse errors: the module must always import; CI tests enforce map completeness instead.
