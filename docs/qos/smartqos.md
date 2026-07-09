# SmartQoS

## Scope

SmartQoS policy lifecycle, limits, scheduling fields, and association
entry points.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMQosPolicy` | List policies or query by name, ID, parent, or vStore | Read | Safe inventory |
| `New-DMQosPolicy` | Create a SmartQoS policy with at least one limit | Mutate | Can throttle workloads |
| `Set-DMQosPolicy` | Rename or modify limits, burst settings, latency, or priority | Mutate | Can throttle workloads |
| `Start-DMQosPolicy`, `Stop-DMQosPolicy` | Start/stop the policy's Running Status (active/inactive); the Enabled field is unchanged | Mutate | Changes live enforcement |
| `Remove-DMQosPolicy` | Delete a policy (must be stopped / Running Status 'Inactive' first) | Mutate | Removes enforcement |
| `Add-DMQosAssociation`, `Remove-DMQosAssociation` | Associate or remove policy from supported objects | Mutate | Changes live enforcement scope |

## Common Workflows

1. Inventory existing policies.
2. Create a policy with conservative limits and a schedule.
3. Associate only test-owned or explicitly approved objects.
4. Start the policy, verify Running Status, and monitor impact.
5. Stop and remove only policies owned by the workflow.

## Examples

```powershell
Get-DMQosPolicy -WebSession $storage

New-DMQosPolicy -WebSession $storage -Name 'test_qos' -MaxIOPS 5000 `
    -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -WhatIf

Set-DMQosPolicy -WebSession $storage -Name 'test_qos' -MaxIOPS 8000 -WhatIf
Stop-DMQosPolicy -WebSession $storage -Name 'test_qos' -WhatIf
```

## Compact Policy Inventory Report

Read-only view of every policy with the fields most useful for an audit:

```powershell
Get-DMQosPolicy -WebSession $storage |
    Select-Object Name, Id, Enabled, 'Running Status', MaxIOPS, MaxBandwidth |
    Format-Table -AutoSize

# Group by enforcement state to spot policies that are enabled but inactive
Get-DMQosPolicy -WebSession $storage |
    Group-Object 'Running Status' |
    Select-Object Name, Count
```

## Glossary

| Term | Meaning |
|---|---|
| Policy | A named SmartQoS object holding one or more limits and an optional schedule. |
| Limit | An upper bound on `MaxIOPS` or `MaxBandwidth` (or a lower-bound service objective). |
| Latency target | Optional maximum latency the policy tries to hold. |
| Burst | Short-term allowance above the steady-state limit. |
| Priority | Relative importance used when the array arbitrates contention. |
| Enabled | Whether the policy is configured for enforcement (distinct from Running Status). |
| Running Status | Live enforcement state: `Active` (enforcing) or `Inactive` (stopped). Changed by `Start-DMQosPolicy` / `Stop-DMQosPolicy`. |
| Association | The link between a policy and a target object (LUN, LUN group, or file system). |
| Schedule | The `StartTime` / `Duration` window during which the policy applies. |
| Parent / child policy | A hierarchy where a child policy inherits or refines a parent's limits. |
| vStore | The tenant scope a policy belongs to; used to query policies per tenant. |

## Safety Notes

Do not test throttle values on production workloads. Prefer short test
windows and test-owned LUNs or file systems.

## Integrity Test Coverage

Read-only integrity validates `Get-DMQosPolicy`. Mutating integrity validates
test-owned SmartQoS policy lifecycle and LUN-group association when enabled.

## Known Gaps

- File-system association is implemented in `New-DMQosPolicy`, but the
  current live mutation workflow focuses on LUN/LUN-group dependencies.
- Operational sizing guidance for limits is not included.

## Related Files

- `POSH-Oceanstor/Public/*Qos*.ps1`
- `Tests/Unit/Public/Qos-actions.Tests.ps1`
- `Tests/Integration/Private/Workflows/QoS.ps1`
