# LUN QoS

## Scope

Using SmartQoS with LUNs and LUN groups.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| `New-DMQosPolicy -LunName/-LunId` | Create policy and attach LUNs | Mutate | Can throttle LUN workloads |
| `Add-DMQosAssociation -LunGroupName/-LunGroupId` | Associate policy with LUN group | Mutate | Can throttle grouped workloads |
| `Remove-DMQosAssociation -LunGroupName/-LunGroupId` | Remove association | Mutate | Changes enforcement scope |

## Common Workflows

1. Create a test-owned LUN and LUN group.
2. Create a QoS policy associated with the LUN.
3. Add or remove a LUN-group association.
4. Disable and remove the policy during cleanup.

## Examples

```powershell
New-DMQosPolicy -WebSession $storage -Name 'test_qos' -MaxIOPS 5000 `
    -LunName 'test_lun_01' -ScheduleStartTime (Get-Date) `
    -StartTime '00:00' -Duration 3600 -WhatIf

Add-DMQosAssociation -WebSession $storage -Name 'test_qos' `
    -LunGroupName 'test_luns' -WhatIf
```

## Safety Notes

Do not associate QoS policies with production LUNs during validation. Policy
settings can affect latency-sensitive workloads immediately.

## Integrity Test Coverage

The QoS mutation workflow creates a policy on the test-owned LUN and
associates it with the test-owned LUN group.

## Known Gaps

- Host and vStore association examples are not covered by current live
  validation notes.

## Related Files

- `POSH-Oceanstor/Public/New-DMQosPolicy.ps1`
- `POSH-Oceanstor/Public/Add-DMQosAssociation.ps1`
- `Tests/Integration/Private/Workflows/QoS.ps1`
