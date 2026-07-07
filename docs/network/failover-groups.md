# Failover Groups

## Scope

Create and manage failover groups — named sets of ports (Ethernet, bond, or
VLAN) across which logical ports (LIFs) fail over when their home port goes
down. Custom failover groups are logical objects; creating an empty one is
low-impact, but membership and assignment changes affect how service IPs move
during failures.

## Cmdlets

| Cmdlet | REST resource | Method | Mutating | ShouldProcess |
|---|---|---|---|---|
| `Get-DMFailoverGroup` | `failovergroup`, `failovergroup/{id}` | GET | No | — |
| `Get-DMFailoverGroupMember` | `eth_port/associate`, `bond_port/associate`, `vlan/associate` | GET | No | — |
| `New-DMFailoverGroup` | `failovergroup` | POST | Yes | Yes |
| `Set-DMFailoverGroup` | `failovergroup/{id}` | PUT | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Remove-DMFailoverGroup` | `failovergroup/{id}` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Add-DMFailoverGroupMember` | `failovergroup/associate` | POST | Yes | Yes |
| `Remove-DMFailoverGroupMember` | `failovergroup/associate?…` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |

Aliases: `Get-DMFailoverGroups`, `Get-DMFailoverGroupMembers`,
`Delete-DMFailoverGroup`, `Delete-DMFailoverGroupMember`.

Key parameters:

- `Get-DMFailoverGroup`: `-Id` (direct lookup), `-Name` (server-side
  `filter=NAME::` match), or all with optional `-RangeStart`/`-RangeEnd`
  paging. Returns `OceanStorFailoverGroup` objects with decoded display
  properties (`Failover Group Type`: System / VLAN / Customized;
  `Service Type`: NAS / BGP; `IP Type`: IPv4 / IPv6).
- `Get-DMFailoverGroupMember`: `-Id` (group ID, pipeline-bindable from
  `Get-DMFailoverGroup`), optional `-MemberType` (213 / 235 / 280) to narrow
  the queried member types. The Dorado 6.1.6 REST reference documents **no**
  GET on `failovergroup/associate`, so the getter uses the documented
  per-type association queries (`eth_port/associate`, `bond_port/associate`,
  `vlan/associate` with `ASSOCIATEOBJTYPE=289`) and aggregates the results as
  `OceanStorFailoverGroupMember` objects (decoded `Member Type` and
  `Running Status`, plus the queried `Failover Group Id`). An empty group
  returns an empty result.
- `New-DMFailoverGroup`: `-Name` (mandatory), `-FailoverGroupType` (only 3 =
  customized is creatable), `-Description`, `-FailoverGroupServiceType`
  (0 = NAS, 3 = BGP), `-FailoverGroupIpType` (0 = IPv4).
- `Set-DMFailoverGroup`: `-Id` (mandatory); modifiable: `-Name`,
  `-Description`.
- `Add/Remove-DMFailoverGroupMember`: `-Id` (group ID),
  `-AssociateObjectType` (213 = Ethernet port, 235 = bond port, 280 = VLAN
  port), `-AssociateObjectId` (port ID).

## Common Workflows

```powershell
# 1. Create a customized group
# 2. Add member ports by ID (Ethernet 213 / bond 235 / VLAN 280)
# 3. Reference the group from New-DMLif -FailoverGroupId
# 4. Tear down in reverse order: members, then group
```

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Read-only — always safe
Get-DMFailoverGroup -WebSession $storage
Get-DMFailoverGroup -WebSession $storage -Name 'fg01'
Get-DMFailoverGroup -WebSession $storage -Id '289:1'

# List a group's current members (Ethernet / bond / VLAN ports)
Get-DMFailoverGroupMember -WebSession $storage -Id '289:1'
Get-DMFailoverGroup -WebSession $storage -Name 'fg01' | Get-DMFailoverGroupMember
Get-DMFailoverGroupMember -WebSession $storage -Id '289:1' -MemberType 213

# Create a customized NAS failover group, capture the object
$fg = New-DMFailoverGroup -WebSession $storage -Name 'fg01' -FailoverGroupServiceType 0

# Add an Ethernet port as a member
Add-DMFailoverGroupMember -WebSession $storage -Id $fg.Id -AssociateObjectType 213 -AssociateObjectId 'eth-id-1'

# Tear down (test-owned objects only), member first, by captured IDs
Remove-DMFailoverGroupMember -WebSession $storage -Id $fg.Id -AssociateObjectType 213 -AssociateObjectId 'eth-id-1'
Remove-DMFailoverGroup -WebSession $storage -Id $fg.Id
```

## Safety Notes

- Classification: **TestOwnedLogicalNetworkMutation** — creating an *empty*
  customized group and deleting it by its captured ID is the safest network
  mutation in this domain and is a candidate for a config-gated live workflow.
- Never modify, delete, or change membership of a **system** failover group or
  any pre-existing group — LIFs actively fail over across them.
- Adding a production port to a test group changes that port's failover
  behavior; only use verified-idle lab ports as test members.
- Delete members before deleting the group; always by the IDs captured at
  creation.

## NAS provisioning walkthrough (failover group → LIF → share)

The typical NAS front-end provisioning order, now verifiable end to end with
the member getter:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# 1. Create the failover group the service IP will move across
$null = New-DMFailoverGroup -WebSession $storage -Name 'nas_fg01' -FailoverGroupServiceType 0
$fg = Get-DMFailoverGroup -WebSession $storage -Name 'nas_fg01'

# 2. Add the front-end ports (Ethernet 213 / bond 235 / VLAN 280) and verify
Add-DMFailoverGroupMember -WebSession $storage -Id $fg.Id -AssociateObjectType 213 -AssociateObjectId 'eth-id-1'
Get-DMFailoverGroupMember -WebSession $storage -Id $fg.Id

# 3. Create the service LIF homed on one member, bound to the group
New-DMLif -WebSession $storage -Name 'nas_lif01' -AddressFamily 0 `
    -IPv4Address '192.0.2.50' -IPv4Mask '255.255.255.0' `
    -HomePortType 1 -HomePortName 'CTE0.A.IOM1.P0' -SupportProtocol 3 `
    -FailoverGroupId $fg.Id

# 4. Expose the share over the new service IP (see docs/nas)
New-DMnfsShare -WebSession $storage -SharePath '/fs01' -FsId '77'
```

Every step above mutates the array — run it only against lab equipment you
own, and tear down in reverse order by captured IDs.

## Integrity Test Coverage

- `Get-DMFailoverGroup` and `Get-DMFailoverGroupMember` are registered in the
  live read-validation phase (expected types `OceanStorFailoverGroup` /
  `OceanStorFailoverGroupMember`).
- All seven cmdlets have unit tests: getter decoding/display set in
  `Tests/Unit/Public/Get-Network.Tests.ps1`, mutators in
  `Tests/Unit/Public/Network-Actions.Tests.ps1`, including
  no-API-call-under-`-WhatIf` regression cases for every mutator.
- A config-gated, test-owned live workflow
  (`Tests/Integration/Private/Workflows/FailoverGroup.ps1`) covers
  create → modify → member-getter round trip → delete by captured ID. It is
  disabled by default behind `Network.Enabled` **and**
  `Network.AllowFailoverGroupLifecycle`; member add/remove stays skipped until
  a test-owned member type exists (see
  [safety-and-live-validation.md](safety-and-live-validation.md)).

## Known Gaps

- Member add/remove is not exercised live: members are ports/bonds/VLANs, and
  the harness never claims a live port. Blocked on the VLAN idle-port guard.
- `failovergroup/associate` has no documented GET in the Dorado 6.1.6 REST
  reference; if Huawei documents one later, the getter can collapse its three
  per-type queries into one call.

## Related Files

- `POSH-Oceanstor/Public/Get-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Get-DMFailoverGroupMember.ps1`
- `POSH-Oceanstor/Private/class-OceanStorFailoverGroupMember.ps1`
- `Tests/Integration/Private/Workflows/FailoverGroup.ps1`
- `POSH-Oceanstor/Public/New-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Set-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Remove-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Add-DMFailoverGroupMember.ps1`
- `POSH-Oceanstor/Public/Remove-DMFailoverGroupMember.ps1`
- `POSH-Oceanstor/Private/class-OceanStorFailoverGroup.ps1`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`
- `Tests/Unit/Public/Get-Network.Tests.ps1`
