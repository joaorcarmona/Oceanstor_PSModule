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
| `New-DMFailoverGroup` | `failovergroup` | POST | Yes | Yes |
| `Set-DMFailoverGroup` | `failovergroup/{id}` | PUT | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Remove-DMFailoverGroup` | `failovergroup/{id}` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |
| `Add-DMFailoverGroupMember` | `failovergroup/associate` | POST | Yes | Yes |
| `Remove-DMFailoverGroupMember` | `failovergroup/associate?…` | DELETE | Yes | Yes (`ConfirmImpact = 'High'`) |

Aliases: `Get-DMFailoverGroups`, `Delete-DMFailoverGroup`,
`Delete-DMFailoverGroupMember`.

Key parameters:

- `Get-DMFailoverGroup`: `-Id` (direct lookup), `-Name` (server-side
  `filter=NAME::` match), or all with optional `-RangeStart`/`-RangeEnd`
  paging. Returns `OceanStorFailoverGroup` objects with decoded display
  properties (`Failover Group Type`: System / VLAN / Customized;
  `Service Type`: NAS / BGP; `IP Type`: IPv4 / IPv6).
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

## Integrity Test Coverage

- `Get-DMFailoverGroup` is registered in the live read-validation phase
  (expected type `OceanStorFailoverGroup`).
- All six cmdlets have unit tests: getter decoding/display set in
  `Tests/Unit/Public/Get-Network.Tests.ps1`, mutators in
  `Tests/Unit/Public/Network-Actions.Tests.ps1`. No live mutation workflow —
  see [TODO.md](TODO.md).

## Known Gaps

- No getter for a group's current members (the `failovergroup/associate` GET
  form is not exposed), so membership can only be inferred from LIF properties.
- No `-WhatIf` regression test asserting the API is not called.

## Related Files

- `POSH-Oceanstor/Public/Get-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/New-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Set-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Remove-DMFailoverGroup.ps1`
- `POSH-Oceanstor/Public/Add-DMFailoverGroupMember.ps1`
- `POSH-Oceanstor/Public/Remove-DMFailoverGroupMember.ps1`
- `POSH-Oceanstor/Private/class-OceanStorFailoverGroup.ps1`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`
- `Tests/Unit/Public/Get-Network.Tests.ps1`
