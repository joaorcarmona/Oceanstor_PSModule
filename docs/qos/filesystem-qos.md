# File-System QoS

## Scope

Using SmartQoS with file systems. The `New-DMQosPolicy` cmdlet supports
`-FileSystemName` and `-FileSystemId` association parameters.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `New-DMQosPolicy -FileSystemName/-FileSystemId` | Create policy and attach file systems | Mutate | Can throttle NAS workloads |
| `Get-DMQosPolicy` | Inventory policies | Read | Safe inventory |
| `Set-DMQosPolicy` | Modify limits | Mutate | Can throttle workloads |

## Common Workflows

1. Inventory file systems.
2. Create a policy with a short schedule and conservative limits.
3. Attach only test-owned or explicitly approved file systems.
4. Monitor NAS performance after enabling.

## Examples

```powershell
New-DMQosPolicy -WebSession $storage -Name 'test_fs_qos' `
    -MaxBandwidth 500 -FileSystemName 'test_fs_01' `
    -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -WhatIf
```

## Safety Notes

File-system QoS can affect many clients at once. Avoid production file systems
unless the storage owner has approved the change.

## Integrity Test Coverage

Unit coverage confirms QoS command behavior. The current live QoS mutation
workflow focuses on LUN/LUN-group objects; file-system QoS association is not
documented as live-validated.

## Known Gaps

- No dedicated file-system QoS live mutation workflow exists today.
- No examples for CIFS/NFS workload-specific tuning are provided.

## Related Files

- `POSH-Oceanstor/Public/New-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Set-DMQosPolicy.ps1`
- `docs/file-storage/file-systems.md`
