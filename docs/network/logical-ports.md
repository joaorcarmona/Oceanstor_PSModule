# Logical Ports (LIFs)

## Scope

Create, modify, and remove logical interface ports (LIFs) — the objects that
carry service IP addresses (NAS, iSCSI, replication, management roles) on top
of Ethernet ports, bonds, or VLANs. LIF mutations directly affect **data
access** and, for management-role LIFs, **management access**.

## Cmdlets

| Cmdlet | REST resource | Method | Mutating | ShouldProcess |
|---|---|---|---|---|
| `Get-DMLif` | `lif`, `lif/{id}` | GET | No | — |
| `New-DMLif` | `lif` | POST | Yes | Yes |
| `Set-DMLif` | `lif` | PUT | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Remove-DMLif` | `lif` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |

Alias: `Delete-DMLif` → `Remove-DMLif`. Alias `Get-DMLifs` → `Get-DMLif`.

Key parameters of `New-DMLif`:

- `-Name` (mandatory), `-AddressFamily` (mandatory; 0 = IPv4, 1 = IPv6),
  `-HomePortType` (mandatory; 1 = Ethernet/RoCE port, 7 = bond port, 8 = VLAN
  port, 25 = VIP, 26 = SIP), plus `-HomePortId`/`-HomePortName` (or
  `-HomeControllerId` for VIP LIFs).
- Addressing: `-IPv4Address`/`-IPv4Mask`/`-IPv4Gateway` or the IPv6
  equivalents.
- `-Role` (1 = management, 2 = service, 3 = management+service,
  4 = replication, 8 = client, 9 = VTEP, 10 = health check),
  `-SupportProtocol` (bit flags: 0 = none, 1 = NFS, 2 = CIFS, 3 = NFS+CIFS,
  4 = iSCSI, 8 = FC/FCoE, 64/512 = reserved/BGP).
- Failover: `-FailoverGroupId`, `-CanFailover`, `-FailbackMode`
  (0 = none, 1 = manual, 2 = auto).
- Multi-vStore / DNS-zone options: `-VstoreId`, `-DdnsStatus`, `-DnsZoneName`,
  `-ListenDnsQueryEnabled`, `-IsPrivate`, `-HomeSiteWwn`.

`Get-DMLif` narrows server-side: `-Name` sends the documented `filter=NAME`
query (exact `::` match, fuzzy `:` for simple leading/trailing `*` wildcards)
and always re-checks the full pattern client-side; `-Id` uses the documented
`lif/{id}` single-object query. `-Ipv4Addr`, `-Ipv6Addr` and `-HomePortId` map
to the documented `IPV4ADDR`, `IPV6ADDR` and `HOMEPORTID` filter fields
respectively; they are sent server-side and compose with `-Name` and with each
other as AND-joined `filter=` clauses.

`Set-DMLif` identifies the LIF by `-Name`, by `-Id`, or both (pipeline-bindable
via the `Id` and `LIF Name` properties of `Get-DMLif` output); it can retarget
the home port (`-HomePortType`/`-HomePortId`/`-HomePortName`), change addresses,
failover behavior, and DNS-zone settings. The REST modify interface documents
`NAME` as a mandatory body field, so `-Id` alone first resolves the current
name through the documented `lif/{id}` query (a read) and then sends the
mutation with both keys — under `-WhatIf` neither call is made. Supplying
neither `-Id` nor `-Name` is an error. `Remove-DMLif` deletes by `-Name`
(with optional `-Id` and `-VstoreId`).

`New-DMLif` returns an `OceanStorLIF` object on success.

## Common Workflows

```powershell
# 1. Choose a home port (read-only): Get-DMPortETH / Get-DMPortBond / Get-DMvLan
# 2. Optionally create a failover group first and pass -FailoverGroupId
# 3. Create the LIF with a unique test name and an unused lab IP
# 4. Verify with Get-DMLif, then Remove-DMLif by that exact name in finally
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only inventory — always safe
Get-DMLif -WebSession $storage

# Preview a NAS LIF creation without touching the array
New-DMLif -WebSession $storage -Name 'lif01' -AddressFamily 0 `
    -IPv4Address '192.0.2.20' -IPv4Mask '255.255.255.0' `
    -HomePortType 1 -HomePortName 'CTE0.A.IOM1.P0' -SupportProtocol 4 -WhatIf

# Modify an existing LIF (prompts; ConfirmImpact = High)
Set-DMLif -WebSession $storage -Name 'lif01' -FailbackMode 2

# Remove by name (test-owned LIFs only)
Remove-DMLif -WebSession $storage -Name 'lif01'
```

## Safety Notes

- Classification: **DataAccessMutation** (and **ManagementAccessMutation** for
  management-role LIFs) — do **not** run live by default.
- A test-owned workflow is possible in a dedicated lab: unique name prefix,
  unused IP subnet, idle home port, removal by the exact created name/ID in
  `finally`. It is not implemented in the integration harness yet.
- Never change the IP address, home port, role, or failover settings of a
  pre-existing LIF — clients mount NAS shares and iSCSI sessions through these
  addresses.
- `Set-DMLif -OperationalStatus $false` deactivates a LIF — treat it as a
  service outage, never run it against a pre-existing LIF.

## Integrity Test Coverage

- `Get-DMLif` is registered in the live read-validation phase (expected type
  `OceanStorLIF`).
- `New/Set/Remove-DMLif` have unit tests in
  `Tests/Unit/Public/Network-Actions.Tests.ps1` (mocked transport, body
  mapping including IPv6 and vStore fields), plus no-API-call-under-`-WhatIf`
  regression cases and `-Id`/`-Name` addressing tests for `Set-DMLif`. No live
  mutation workflow — intentional; the harness reports these mutators
  `SkippedUnsafe`.

## Friendly Names and Display Fields

- Use **ID parameters for automation.** `-HomePortId` and `-Id` address the
  documented stable identifiers; `-HomePortName` is a convenience lookup that
  resolves to the same ID. When a workflow captures a LIF or home port, retain
  its `Id`/`HomePortId` and pass that back rather than a display name.
- Decoded display fields (home-port type, role) are for operator readability;
  the REST API still expects the underlying ID or enum, so do not build mutation
  workflows on display strings.

## Known Gaps

- None outstanding for read filters — `NAME`, `IPV4ADDR`, `IPV6ADDR` and
  `HOMEPORTID` are all exposed as server-side `filter=` parameters.

## Related Files

- `POSH-Oceanstor/Public/Get-DMLif.ps1`
- `POSH-Oceanstor/Public/New-DMLif.ps1`
- `POSH-Oceanstor/Public/Set-DMLif.ps1`
- `POSH-Oceanstor/Public/Remove-DMLif.ps1`
- `POSH-Oceanstor/Private/class-OceanstorLIF.ps1`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`
