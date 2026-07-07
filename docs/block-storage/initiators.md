# Initiators

## Scope

Fibre Channel, iSCSI, and NVMe initiator inventory and test-owned lifecycle.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMHostInitiator` | Generic initiator inventory by protocol | Read | Safe inventory |
| `Get-DMFiberChannelInitiator`, `Get-DMIscsiInitiator`, `Get-DMNvmeInitiator` | Protocol-specific inventory | Read | Safe inventory |
| `New-DMFiberChannelInitiator`, `New-DMIscsiInitiator`, `New-DMNvmeInitiator` | Create/register free initiator | Mutate | Access-path mutation |
| `Remove-DMFiberChannelInitiator`, `Remove-DMIscsiInitiator`, `Remove-DMNvmeInitiator` | Remove initiator object | Mutate | Access-path mutation |
| `Remove-DMFiberChannelInitiatorFromHost`, `Remove-DMIscsiInitiatorFromHost`, `Remove-DMNvmeInitiatorFromHost` | Detach from host | Mutate | Can disrupt access |

## Common Workflows

1. Inventory free initiators.
2. Register a known unused initiator.
3. Attach it to a test-owned host during provisioning.
4. Detach and remove it only if the workflow owns it.

## Examples

```powershell
Get-DMFiberChannelInitiator -WebSession $storage -FreeInitiators
Get-DMIscsiInitiator -WebSession $storage -FreeInitiators
Get-DMNvmeInitiator -WebSession $storage -FreeInitiators

New-DMIscsiInitiator -WebSession $storage -Identifier 'iqn.2003-01.com.example' `
    -Name 'test_iqn' -HostName 'test_host_01' -WhatIf
```

## Safety Notes

Initiator changes can remove storage access from a host. The integration
harness requires explicit configured unused identities for FC, iSCSI, and
NVMe validation.

## Integrity Test Coverage

Read-only integrity validates FC, iSCSI, NVMe, and generic host-initiator
getters. Mutating integrity can validate free initiator lifecycle when
`Initiators.Enabled = $true` and protocol identities are configured. FC and
iSCSI detach coverage also depends on `Host.Enabled`.

## Known Gaps

- Live workflow coverage is skipped as `NotConfigured` when protocol identity
  values are blank.
- Production initiator migration procedures are not documented.

## Related Files

- `POSH-Oceanstor/Public/*Initiator*.ps1`
- `Tests/Integration/Private/Workflows/Initiators.ps1`
- `Tests/Unit/Public/initiator-actions.Tests.ps1`
