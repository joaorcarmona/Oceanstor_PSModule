# QoS Policies

## Scope

Policy settings: I/O type, bandwidth, IOPS, latency, burst behavior, priority,
schedule, and vStore scoping.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `New-DMQosPolicy` | Create a policy with `MaxBandwidth`, `MaxIOPS`, `MinBandwidth`, `MinIOPS`, or `Latency` | Mutate | Can throttle workloads |
| `Set-DMQosPolicy` | Modify the same limit family plus burst and priority settings | Mutate | Can throttle workloads |
| `Start-DMQosPolicy`, `Stop-DMQosPolicy` | Start or stop the policy's Running Status (active/inactive). Do not change the Enabled field | Mutate | Changes live behavior |
| `Remove-DMQosPolicy` | Delete policy (policy must be stopped / Running Status 'Inactive' first) | Mutate | Removes enforcement |

## Common Workflows

1. Create the policy stopped or with a short schedule when possible.
2. Read back policy state (Running Status).
3. Update limits gradually.
4. Stop the policy before cleanup (removal requires Running Status 'Inactive').

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
create, update, start, stop, association, and removal for test-owned
objects.

## Known Gaps

- No public sizing calculator is provided.
- Weekly schedule examples are not included beyond parameter availability.

## Related Files

- `POSH-Oceanstor/Public/New-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Set-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Start-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Stop-DMQosPolicy.ps1`
