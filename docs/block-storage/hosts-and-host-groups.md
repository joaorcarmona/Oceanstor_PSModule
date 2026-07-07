# Hosts and Host Groups

## Scope

Host and host-group inventory, lifecycle, and membership.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMhost` | List hosts or query by ID, name, filter, or host group | Read | Safe inventory |
| `Get-DMhostbyFilter`, `Get-DMhostbyId`, `Get-DMhostbyName`, `Get-DMhostbyHostGroup` | Legacy lookup wrappers | Read | Safe inventory |
| `Get-DMhostGroup` | List or query host groups | Read | Safe inventory |
| `Get-DMHostLink` | List host links by host and protocol | Read | Safe inventory |
| `New-DMHost`, `Set-DMHost`, `Rename-DMHost`, `Remove-DMHost` | Host lifecycle | Mutate | Access-path mutation |
| `New-DMHostGroup`, `Set-DMHostGroup`, `Rename-DMHostGroup`, `Remove-DMHostGroup` | Host-group lifecycle | Mutate | Access-path mutation |
| `Add-DMHostToHostGroup`, `Remove-DMHostFromHostGroup` | Membership changes | Mutate | Access-path mutation |
| `Get-DMHostPerformance` | Realtime host performance wrapper | Read | Safe when performance collection is expected |

## Common Workflows

1. Inventory hosts and host groups.
2. Create a host group for an application or cluster.
3. Create hosts with the correct operating system.
4. Attach initiators to hosts.
5. Add hosts to the host group.
6. Use mapping views or direct mapping for LUN access.

## Examples

```powershell
Get-DMhost -WebSession $storage
Get-DMhostGroup -WebSession $storage
Get-DMhost -WebSession $storage -HostGroupName 'app_hosts'

New-DMHostGroup -WebSession $storage -Name 'test_hosts' -WhatIf
New-DMHost -WebSession $storage -Name 'test_host_01' -OperatingSystem Linux -WhatIf
Add-DMHostToHostGroup -WebSession $storage -HostName 'test_host_01' `
    -HostGroupName 'test_hosts' -WhatIf
```

## Safety Notes

Changing host membership can change which initiators receive storage. Do not
remove or rename production hosts or host groups from automated validation.

## Integrity Test Coverage

Read-only integrity validates host, host-group, and host-link getters.
Mutating integrity has a test-owned host and host-group workflow gated by
`Host.Enabled`. Unit tests cover getters, host-group membership, removal, and
performance wrappers.

## Known Gaps

- Host operating-system enum behavior is not deeply documented here.
- Live initiator attachment depends on configured free initiator identities.

## Related Files

- `POSH-Oceanstor/Public/Get-DMhost.ps1`
- `POSH-Oceanstor/Public/Get-DMhostGroup.ps1`
- `POSH-Oceanstor/Public/New-DMHost.ps1`
- `POSH-Oceanstor/Public/New-DMHostGroup.ps1`
- `Tests/Integration/Private/Workflows/Host.ps1`
