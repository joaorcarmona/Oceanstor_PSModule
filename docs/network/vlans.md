# VLAN Ports

## Scope

Create, modify, and remove VLAN ports layered on top of Ethernet or bond
ports. A VLAN port is a logical child of a physical/bond port; creating one on
an idle port is low-impact, but VLANs on ports that carry traffic affect data
access.

## Cmdlets

| Cmdlet | REST resource | Method | Mutating | ShouldProcess |
|---|---|---|---|---|
| `Get-DMvLan` | `vlan` | GET | No | — |
| `New-DMvLan` | `vlan` | POST | Yes | Yes |
| `Set-DMvLan` | `vlan/{id}` | PUT | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Remove-DMvLan` | `vlan/{id}` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |

Alias: `Delete-DMvLan` → `Remove-DMvLan`.

Key parameters:

- `New-DMvLan`: `-Tag` (mandatory, 1–4094), `-PortType` (mandatory; 1 =
  Ethernet port, 7 = bond port), `-PortId` (mandatory, parent port ID).
  Returns an `OceanStorvLan` object on success.
- `Set-DMvLan`: `-Id` (mandatory), `-Mtu` (mandatory, 1280–9000). MTU is the
  only modifiable property.
- `Remove-DMvLan`: `-Id` (mandatory).

## Common Workflows

```powershell
# 1. Pick the parent port ID (read-only)
Get-DMPortETH -WebSession $storage      # or Get-DMPortBond

# 2. Create the VLAN, capture its ID from the returned object
# 3. Layer a LIF on it (HomePortType 8) or add it to a failover group
# 4. Remove by captured ID when done
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only inventory — always safe
Get-DMvLan -WebSession $storage

# Preview without touching the array
New-DMvLan -WebSession $storage -Tag 100 -PortType 1 -PortId 'eth-id-1' -WhatIf

# Create (mutating — lab only), capture the ID immediately
$vlan = New-DMvLan -WebSession $storage -Tag 100 -PortType 1 -PortId 'eth-id-1'

# Modify MTU / remove, always by captured ID
Set-DMvLan -WebSession $storage -Id $vlan.Id -Mtu 9000
Remove-DMvLan -WebSession $storage -Id $vlan.Id
```

## Safety Notes

- Classification: **VlanMutation** — live testing is allowed only as a
  test-owned workflow: create a VLAN with a unique tag on a verified-idle
  port, capture the ID, and delete that exact ID in `finally`. Otherwise skip.
- Never change the MTU of, or delete, a pre-existing VLAN — production traffic
  may be using it.
- Creating a VLAN attaches a logical child to a physical port; prefer
  known-idle lab ports.

## Integrity Test Coverage

- `Get-DMvLan` is registered in the live read-validation phase (expected type
  `OceanStorvLan`).
- `New/Set/Remove-DMvLan` have unit tests in
  `Tests/Unit/Public/Network-Actions.Tests.ps1`. No live mutation workflow
  exists — intentional.

## Known Gaps

- No `-WhatIf` regression test asserting the API is not called.
- `Set-DMvLan` exposes only MTU; name/description changes are not supported by
  the API for VLAN ports.

## Related Files

- `POSH-Oceanstor/Public/Get-DMvLan.ps1`
- `POSH-Oceanstor/Public/New-DMvLan.ps1`
- `POSH-Oceanstor/Public/Set-DMvLan.ps1`
- `POSH-Oceanstor/Public/Remove-DMvLan.ps1`
- `POSH-Oceanstor/Private/class-OceanStorvlLan.ps1`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`
