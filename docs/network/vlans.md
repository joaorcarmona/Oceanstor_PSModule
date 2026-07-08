# VLAN Ports

## Scope

Create, modify, and remove VLAN ports layered on top of Ethernet or bond
ports. A VLAN port is a logical child of a physical/bond port; creating one on
an idle port is low-impact, but VLANs on ports that carry traffic affect data
access.

## Cmdlets

| Cmdlet | REST resource | Method | Mutating | ShouldProcess |
|---|---|---|---|---|
| `Get-DMvLan` | `vlan`, `vlan/{id}` | GET | No | — |
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
  `OceanStorvLan`). It narrows server-side: `-Name` sends the documented
  `filter=NAME` query (exact `::`, fuzzy `:` for simple leading/trailing `*`
  wildcards, always re-checked client-side) and `-Id` uses the documented
  `vlan/{id}` single-object query. `-Tag` and `-FatherDrvType` map to the
  documented `TAG` and `fatherDrvType` filter fields; they are sent server-side
  and compose with `-Name` and each other as AND-joined `filter=` clauses.
- `New/Set/Remove-DMvLan` have unit tests in
  `Tests/Unit/Public/Network-Actions.Tests.ps1`, including
  no-API-call-under-`-WhatIf` regression cases. No live mutation workflow
  runs yet: the idle-port guard it depends on
  (`Get-DMVlanParentPortStatus`) is now implemented and unit-tested, and the
  `Network.AllowVlanLifecycle` gate is defined but defaults off. The live
  create/delete run stays deferred to a supervised session — see
  [safety-and-live-validation.md](safety-and-live-validation.md).

## Friendly Names and Display Fields

- **Enum parameters take raw values today.** `-PortType` and `-FatherDrvType`
  accept the numeric / documented API values (e.g. `-PortType 1`), not
  friendly-name aliases. A friendly-name convenience layer (for example
  `-FatherDrvType HostService`) with back-compat for numeric values is a
  planned, **not-yet-implemented** enhancement — do not assume it exists; pass
  the documented value.
- **Display fields are for readers, IDs are for automation.** `OceanStorvLan`
  currently surfaces some attributes (running status, MTU) as raw fields rather
  than decoded display strings the way `OceanStorFailoverGroup` does; richer
  decoding is a deferred display-field enhancement. When a value is decoded for
  readability, the REST API still expects the underlying ID or enum — keep and
  pass the stable `Id`/`PortId` in automation rather than a display string.

## Known Gaps

- `Set-DMvLan` exposes only MTU; name/description changes are not supported by
  the API for VLAN ports.
- Read filters `NAME`, `TAG` and `fatherDrvType` are all exposed as server-side
  `filter=` parameters; no read-filter gap remains.

## Related Files

- `POSH-Oceanstor/Public/Get-DMvLan.ps1`
- `POSH-Oceanstor/Public/New-DMvLan.ps1`
- `POSH-Oceanstor/Public/Set-DMvLan.ps1`
- `POSH-Oceanstor/Public/Remove-DMvLan.ps1`
- `POSH-Oceanstor/Private/class-OceanStorvlLan.ps1`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`
