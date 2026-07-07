# Snapshot Schedules

## Scope

HyperCDP schedule cmdlets for block LUN snapshot scheduling. No separate
general snapshot policy/schedule cmdlet family was confirmed.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `Get-DMHyperCDPSchedule` | List or query HyperCDP schedules | Read | Safe inventory |
| `New-DMHyperCDPSchedule` | Create a schedule | Mutate | Can create recurring recovery points |
| `Set-DMHyperCDPSchedule` | Modify schedule settings | Mutate | Changes recurrence/retention behavior |
| `Enable-DMHyperCDPSchedule`, `Disable-DMHyperCDPSchedule` | Toggle schedule | Mutate | Changes snapshot creation |
| `Add-DMLunToHyperCDPSchedule`, `Remove-DMLunFromHyperCDPSchedule` | Manage scheduled LUN membership | Mutate | Changes protected scope |
| `Remove-DMHyperCDPSchedule` | Delete schedule | Mutate | Removes scheduling object |

## Common Workflows

1. Create a disabled schedule for a test-owned LUN.
2. Add the LUN to the schedule.
3. Remove the LUN.
4. Toggle schedule state only in isolated validation.
5. Delete the schedule by captured identity.

## Examples

```powershell
Get-DMHyperCDPSchedule -WebSession $storage

New-DMHyperCDPSchedule -WebSession $storage -Name 'test_hypercdp' `
    -ObjectType Lun -FrequencyValueSeconds 3600 -FrequencySnapshotCount 2 -WhatIf

Add-DMLunToHyperCDPSchedule -WebSession $storage -LunName 'test_lun_01' `
    -ScheduleName 'test_hypercdp' -WhatIf
```

## Safety Notes

Schedules can create recurring recovery points and consume capacity. The
default integrity config disables HyperCDP schedule mutation.

## Integrity Test Coverage

Read-only integrity validates `Get-DMHyperCDPSchedule`. Mutating integrity
validates non-secure block HyperCDP schedule lifecycle only when
`HyperCDPSchedule.Enabled` and `Lun.Enabled` are true.

## Known Gaps

- General snapshot policy/schedule cmdlets were not found beyond HyperCDP.
- Secure snapshot schedule behavior is intentionally not covered by the
  current workflow.

## Related Files

- `POSH-Oceanstor/Public/*HyperCDPSchedule*.ps1`
- `Tests/Unit/Public/HyperCDPSchedule.Tests.ps1`
- `Tests/Integration/Private/Workflows/HyperCDPSchedule.ps1`
