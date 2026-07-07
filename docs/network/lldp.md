# LLDP Working Mode

## Scope

Query and change the array-wide LLDP (Link Layer Discovery Protocol) working
mode. This is a single **global** network setting, not a per-port object.

## Cmdlets

| Cmdlet | REST resource | Method | Mutating | ShouldProcess |
|---|---|---|---|---|
| `Get-DMLLDPWorkingMode` | `LLDP_WORKING_MODE` | GET | No | — |
| `Set-DMLLDPWorkingMode` | `LLDP_WORKING_MODE` | PUT | Yes | Yes (`ConfirmImpact = 'High'`) |

- `Get-DMLLDPWorkingMode` returns a `pscustomobject` with `WorkingMode` (0–3),
  `WorkingModeName` (`Disabled` / `Transmit` / `Receive` /
  `TransmitReceive`), and the raw `lldpWorkingMode` value.
- `Set-DMLLDPWorkingMode -WorkingMode` accepts either the numeric value
  (`'0'`–`'3'`) or the friendly name (`Disabled`, `Transmit`, `Receive`,
  `TransmitReceive`).

## Common Workflows

- Read the current mode as part of a network inventory.
- Align LLDP mode with switch-fabric discovery policy (change windows only).

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only — always safe
Get-DMLLDPWorkingMode -WebSession $storage

# Preview a change without touching the array
Set-DMLLDPWorkingMode -WebSession $storage -WorkingMode Transmit -WhatIf
```

## Safety Notes

- Classification: get = **ReadOnlyNetworkStatus** (safe live); set = global
  network mutation — do **not** run live by default. There is no test-owned
  variant: the setting is array-wide, so any change affects the shared
  environment and there is no "created object" to clean up.
- If a live check were ever required, it would need to capture the original
  mode and restore it — this restore-style pattern still mutates pre-existing
  configuration and is therefore excluded from the validation harness.

## Integrity Test Coverage

- `Get-DMLLDPWorkingMode` is registered in the live read-validation phase
  (expected type `PSCustomObject`).
- Unit tests: getter in `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`,
  setter in `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1` (asserts PUT
  body value mapping).

## Known Gaps

- Per-port LLDP neighbor information is not exposed.

## Related Files

- `POSH-Oceanstor/Public/Get-DMLLDPWorkingMode.ps1`
- `POSH-Oceanstor/Public/Set-DMLLDPWorkingMode.ps1`
- `Tests/Unit/Public/Get-SystemConfiguration.Tests.ps1`
- `Tests/Unit/Public/Set-SystemConfiguration.Tests.ps1`
