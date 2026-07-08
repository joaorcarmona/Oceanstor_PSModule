# Bond Ports (Link Aggregation)

## Scope

Create, modify, and remove bond ports — link aggregations of physical Ethernet
ports. Bond mutations consume and reconfigure **physical ports** and are
therefore unsafe to run live by default.

## Cmdlets

| Cmdlet | REST resource | Method | Mutating | ShouldProcess |
|---|---|---|---|---|
| `Get-DMPortBond` | `bond_port` | GET | No | — |
| `New-DMPortBond` | `bond_port` | POST | Yes | Yes |
| `Set-DMPortBond` | `bond_port` / `bond_port/{id}` | PUT | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Remove-DMPortBond` | `bond_port` / `bond_port/{id}` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |

Alias: `Delete-DMPortBond` → `Remove-DMPortBond`.

Key parameters:

- `New-DMPortBond`: `-Name` (optional, 1–31 chars), `-PortIdList` (mandatory,
  Ethernet port IDs), `-BondPortType` (1 = host/service bond, 2 = switch bond,
  4 = CloudVxLAN bond), `-MsgReturnType`.
- `Set-DMPortBond`: identify by `-Id` or `-Name` (parameter sets); modifiable:
  `-Mtu` (1280–9000), `-IPv4Address`/`-IPv4Mask`, `-IPv6Address`/`-IPv6Mask`,
  `-UsedType`.
- `Remove-DMPortBond`: identify by `-Id` (URL path) or `-Name` (request body).

`New-DMPortBond` returns an `OceanStorPortBond` object on success.

## Common Workflows

```powershell
# 1. Find candidate Ethernet ports (read-only)
Get-DMPortETH -WebSession $storage

# 2. Create the bond from captured port IDs
# 3. Verify, then modify or remove by the captured bond ID
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only inventory — always safe
Get-DMPortBond -WebSession $storage

# Preview a bond creation without touching the array
New-DMPortBond -WebSession $storage -Name 'bond01' -PortIdList 'eth-id-1', 'eth-id-2' -BondPortType 1 -WhatIf

# Create (mutating — lab only), capture the ID immediately
$bond = New-DMPortBond -WebSession $storage -Name 'bond01' -PortIdList 'eth-id-1', 'eth-id-2' -BondPortType 1

# Modify MTU by captured ID (prompts unless -Confirm:$false)
Set-DMPortBond -WebSession $storage -Id $bond.Id -Mtu 9000

# Remove by captured ID
Remove-DMPortBond -WebSession $storage -Id $bond.Id
```

## Safety Notes

- Classification: **BondOrAggregationMutation** — do **not** run live by
  default. Creating a bond changes how its member physical ports carry traffic;
  removing one can drop service connectivity.
- Do not create bonds from ports that carry management or production traffic.
- Do not use Ethernet ports on FCoE interface modules to create bond ports
  (array-side restriction).
- Never modify or remove a bond you did not create in the same validation run.

## Integrity Test Coverage

- `Get-DMPortBond` is registered in the live read-validation phase
  (expected type `OceanStorPortBond`).
- `New/Set/Remove-DMPortBond` have unit tests in
  `Tests/Unit/Public/Network-Actions.Tests.ps1` (mocked transport; asserts
  method, resource, and body mapping), including no-API-call-under-`-WhatIf`
  regression cases and a `Get-DMPortBond | Remove-DMPortBond` pipeline test.
  No live mutation workflow exists — intentional.

## Friendly Names and Display Fields

- **`-BondPortType` takes raw values today.** Pass the documented numeric value
  (`1` = host/service, `2` = ...), not a friendly-name alias. A friendly-name
  convenience layer such as `-BondPortType HostService` with back-compat for the
  numeric values is a planned, **not-yet-implemented** enhancement — do not
  assume it exists.
- **Display fields are for readers, IDs are for automation.** `OceanStorPortBond`
  currently surfaces some attributes (running status, MTU) as raw fields rather
  than decoded display strings the way `OceanStorFailoverGroup` does; richer
  decoding is a deferred display-field enhancement. Where a value is decoded for
  readability, the REST API still expects the underlying ID or enum — keep and
  pass the stable `Id`/`PortId` in automation rather than a display string.

## Known Gaps

- Bond member add/remove after creation is **not implemented**: the Dorado
  6.1.6 REST reference documents the bond port modify interface
  (`PUT bond_port/{id}`) with `NAME`, `MTU`, IPv4/IPv6 address fields and
  `MSGRETURNTYPE`/`USEDTYPE` only — no `PORTIDLIST` or member operation.
  Changing membership requires delete + recreate. Deferred until Huawei
  documents a member endpoint (verified 2026-07-07).

## Related Files

- `POSH-Oceanstor/Public/Get-DMPortBond.ps1`
- `POSH-Oceanstor/Public/New-DMPortBond.ps1`
- `POSH-Oceanstor/Public/Set-DMPortBond.ps1`
- `POSH-Oceanstor/Public/Remove-DMPortBond.ps1`
- `POSH-Oceanstor/Private/class-OceanstorPortBond.ps1`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`
