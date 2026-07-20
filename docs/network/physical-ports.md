# Physical Ports (Ethernet, Fibre Channel, SAS)

## Scope

Read-only inventory of the array's physical front-end and back-end ports and
the interface modules that host them. **No cmdlet in this module mutates a
physical port** — port enable/disable, MTU, speed, and IP changes on physical
ports are deliberately not implemented (see [CHANGELOG.md](../../CHANGELOG.md), "Standing safety reference").

## Cmdlets

| Cmdlet | REST resource | Output class | Mutating |
|---|---|---|---|
| `Get-DMPortETH` | `eth_port` | `OceanStorPortETH` | No |
| `Get-DMPortFc` | `fc_port` | `OceanStorPortFC` | No |
| `Get-DMPortSAS` | `sas_port` | `OceanstorPortSAS` | No |
| `Get-DMInterfaceModule` | `intf_module` | `OceanstorInterfaceModule` | No |

All four accept `-WebSession` (optional when a single session is active) and an
optional positional `-Name` to filter to a single port location.

## Common Workflows

- Inventory all front-end ports before planning bonds, VLANs, or LIF home
  ports.
- Capture port IDs (`Id` property) — bond, VLAN, and failover-group cmdlets
  reference ports by ID, not name.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# All Ethernet ports
Get-DMPortETH -WebSession $storage

# A single port by location name
Get-DMPortETH -WebSession $storage 'CTE0.A.IOM1.P0'

# Fibre Channel and SAS inventory
Get-DMPortFc -WebSession $storage
Get-DMPortSAS -WebSession $storage
```

## Safety Notes

- Classification: **ReadOnlyNetworkInventory** — safe to run live at any time.
- These getters issue only `GET` requests and change nothing on the array.

## Integrity Test Coverage

- `Get-DMPortETH`, `Get-DMPortFc`, `Get-DMPortSAS`, and `Get-DMInterfaceModule`
  are registered in the read-validation phase of
  `Tests/Integration/Invoke-GetterIntegrityValidation.ps1` with their expected
  output types.
- Unit tests: `Tests/Unit/Public/Get-Network.Tests.ps1`.

## Known Gaps

- No cmdlet exposes port health/BER counters or per-port performance
  statistics.
- No physical-port mutation cmdlets exist (intentional — see
  [CHANGELOG.md](../../CHANGELOG.md) "Standing safety reference").

## Related Files

- `POSH-Oceanstor/Public/Get-DMPortETH.ps1`
- `POSH-Oceanstor/Public/Get-DMPortFc.ps1`
- `POSH-Oceanstor/Public/Get-DMPortSAS.ps1`
- `POSH-Oceanstor/Public/Get-DMInterfaceModule.ps1`
- `Tests/Unit/Public/Get-Network.Tests.ps1`
