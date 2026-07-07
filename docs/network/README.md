# Network Documentation

This folder documents the **array network** domain of POSH-Oceanstor: cmdlets
that inspect or configure the storage array's front-end connectivity — physical
ports, bond ports, VLANs, logical interfaces (LIFs), failover groups, and LLDP.

> **Safety warning** — network mutations can break management access, NAS/iSCSI
> data access, or replication traffic. Every mutating cmdlet in this domain
> supports `-WhatIf`/`-Confirm`, and most are `ConfirmImpact = 'High'`. Read
> [safety-and-live-validation.md](safety-and-live-validation.md) before running
> any `New-`/`Set-`/`Remove-` cmdlet against a shared array. Live mutation tests
> are **opt-in and unsafe by default**.

## Domains

| Document | Domain | Cmdlets | Mutations |
|---|---|---|---|
| [physical-ports.md](physical-ports.md) | Ethernet / FC / SAS ports, interface modules | `Get-DMPortETH`, `Get-DMPortFc`, `Get-DMPortSAS`, `Get-DMInterfaceModule` | Read-only |
| [bond-ports.md](bond-ports.md) | Bond ports (link aggregation) | `Get-DMPortBond`, `New-DMPortBond`, `Set-DMPortBond`, `Remove-DMPortBond` | Yes — unsafe by default |
| [vlans.md](vlans.md) | VLAN ports | `Get-DMvLan`, `New-DMvLan`, `Set-DMvLan`, `Remove-DMvLan` | Yes — test-owned only |
| [logical-ports.md](logical-ports.md) | Logical interface ports (LIFs) | `Get-DMLif`, `New-DMLif`, `Set-DMLif`, `Remove-DMLif` | Yes — test-owned only |
| [failover-groups.md](failover-groups.md) | Failover groups and port membership | `Get-DMFailoverGroup`, `New-DMFailoverGroup`, `Set-DMFailoverGroup`, `Remove-DMFailoverGroup`, `Add-DMFailoverGroupMember`, `Remove-DMFailoverGroupMember` | Yes — test-owned only |
| [lldp.md](lldp.md) | LLDP working mode (global) | `Get-DMLLDPWorkingMode`, `Set-DMLLDPWorkingMode` | Yes — global setting, unsafe by default |
| [safety-and-live-validation.md](safety-and-live-validation.md) | Safety classification and live-validation rules | — | — |
| [TODO.md](TODO.md) | Roadmap and open gaps for this domain | — | — |

Related domains documented elsewhere: DNS servers (`Get-DMdnsServer`,
`Set-DMdnsServer`) belong to the system-management docs; port groups and
iSCSI/NVMe/FC initiators belong to the host-mapping domain.

## Connecting

All examples in this folder assume a connected DeviceManager session:

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru
# Lab arrays with self-signed certificates: add -SkipCertificateCheck
```

The `-WebSession` parameter is optional when only one array session is active;
pass it explicitly when working with multiple arrays.

## Quick read-only inventory

All of these are safe against any array:

```powershell
Get-DMPortETH -WebSession $storage          # Ethernet ports
Get-DMPortFc -WebSession $storage           # Fibre Channel ports
Get-DMPortSAS -WebSession $storage          # SAS ports
Get-DMPortBond -WebSession $storage         # Bond ports
Get-DMvLan -WebSession $storage             # VLAN ports
Get-DMLif -WebSession $storage              # Logical interfaces
Get-DMFailoverGroup -WebSession $storage    # Failover groups
Get-DMLLDPWorkingMode -WebSession $storage  # LLDP working mode
Get-DMInterfaceModule -WebSession $storage  # Interface modules
```

## Conventions in this domain

- Every mutating cmdlet declares `SupportsShouldProcess`; destructive or
  in-place modifications additionally declare `ConfirmImpact = 'High'`, so they
  prompt unless `-Confirm:$false` is passed.
- `Remove-*` cmdlets also export a `Delete-*` alias
  (`Delete-DMPortBond`, `Delete-DMvLan`, `Delete-DMLif`,
  `Delete-DMFailoverGroup`, `Delete-DMFailoverGroupMember`).
- Getters return typed output classes (`OceanStorPortETH`, `OceanStorPortBond`,
  `OceanStorvLan`, `OceanStorLIF`, `OceanStorFailoverGroup`) defined in
  `POSH-Oceanstor/Private/class-*.ps1`; `Get-DMLLDPWorkingMode` returns a
  plain `pscustomobject`.
- Request bodies are built from bound parameters via the shared
  `ConvertTo-DMRequestBody` helper, so unset parameters are never sent to the
  array.

## Testing

Unit tests for this domain live in
`Tests/Unit/Public/Network-Actions.Tests.ps1` (mutators),
`Tests/Unit/Public/Get-Network.Tests.ps1` (getters), and the
`Get/Set-SystemConfiguration.Tests.ps1` files (LLDP). Read-only getters are
registered in the live getter-integrity harness
(`Tests/Integration/Invoke-GetterIntegrityValidation.ps1`); network mutators
are intentionally **not** part of any live mutation workflow. See
[safety-and-live-validation.md](safety-and-live-validation.md).

## Roadmap

Open gaps and planned work: [Network TODO](TODO.md)
