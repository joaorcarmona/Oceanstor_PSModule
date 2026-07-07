# QoS Policies

## Scope

Policy settings: I/O type, bandwidth, IOPS, latency, burst behavior, priority,
schedule, and vStore scoping.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `New-DMQosPolicy` | Create a policy with `MaxBandwidth`, `MaxIOPS`, `MinBandwidth`, `MinIOPS`, or `Latency` | Mutate | Can throttle workloads |
| `Set-DMQosPolicy` | Modify the same limit family plus burst and priority settings | Mutate | Can throttle workloads |
| `Enable-DMQosPolicy`, `Disable-DMQosPolicy` | Toggle enforcement | Mutate | Changes live behavior |
| `Remove-DMQosPolicy` | Delete policy | Mutate | Removes enforcement |

## Common Workflows

1. Create the policy disabled or with a short schedule when possible.
2. Read back policy state.
3. Update limits gradually.
4. Disable before cleanup.

## Examples

```powershell
New-DMQosPolicy -WebSession $storage -Name 'test_qos' `
    -MaxBandwidth 500 -BurstBandwidth 800 -BurstTime 60 `
    -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -WhatIf

Set-DMQosPolicy -WebSession $storage -Name 'test_qos' `
    -Priority High -Latency 1500 -WhatIf
```

## Safety Notes

`Min*` settings can reserve service behavior and `Max*` settings can throttle.
Confirm units before applying changes.

## Integrity Test Coverage

Unit tests cover policy action behavior. The live QoS workflow validates
create, update, enable, disable, association, and removal for test-owned
objects.

## Known Gaps

- No public sizing calculator is provided.
- Weekly schedule examples are not included beyond parameter availability.

## Related Files

- `POSH-Oceanstor/Public/New-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Set-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Enable-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Disable-DMQosPolicy.ps1`
