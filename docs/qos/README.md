# QoS Documentation

This folder documents POSH-Oceanstor SmartQoS cmdlets. QoS is implemented for
policy lifecycle, policy modification, start/stop (Running Status), removal,
associations, and optional association at policy creation time with LUNs or
file systems.

## Documentation Map

| Document | Domain | Implemented? |
|---|---|---|
| [smartqos.md](smartqos.md) | SmartQoS policy lifecycle and limits | Yes |
| [qos-policies.md](qos-policies.md) | Policy settings, schedule, and start/stop | Yes |
| [lun-qos.md](lun-qos.md) | LUN and LUN-group QoS usage | Yes |
| [filesystem-qos.md](filesystem-qos.md) | File-system QoS attachment | Partial |
| [safety-and-live-validation.md](safety-and-live-validation.md) | Safety rules for live arrays | - |
| [CHANGELOG.md](../../CHANGELOG.md) | Consolidated changelog — completed work, deferred items, safety reference | - |

## Connecting

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"

$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru
# Lab arrays with self-signed certificates: add -SkipCertificateCheck
```

## Quick Read-Only Inventory

```powershell
Get-DMQosPolicy -WebSession $storage
Get-DMQosPolicy -WebSession $storage -Name 'qos_policy_01'
```

## Implemented Cmdlet Areas

| Area | Cmdlets |
|---|---|
| Policy lifecycle | `Get-DMQosPolicy`, `New-DMQosPolicy`, `Set-DMQosPolicy`, `Remove-DMQosPolicy` |
| Policy running state | `Start-DMQosPolicy`, `Stop-DMQosPolicy` |
| Associations | `Add-DMQosAssociation`, `Remove-DMQosAssociation` |
| LUN/file-system attachment at creation | `New-DMQosPolicy -LunName`, `-LunId`, `-FileSystemName`, `-FileSystemId` |

## Safety in One Paragraph

QoS mutators can throttle production workloads or change minimum service
objectives. Always preview examples with `-WhatIf`, use conservative test
limits, and avoid associating policies with existing production objects during
validation.
