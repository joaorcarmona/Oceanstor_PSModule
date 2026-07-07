# QoS Safety and Live Validation

QoS settings can reduce IOPS, bandwidth, or latency allowance for production
workloads. They are safe to read but not casual to change.

## Rules

1. `Get-DMQosPolicy` is generally safe.
2. Mutating commands require explicit user intent.
3. Use `-WhatIf` while learning `New-*`, `Set-*`, `Enable-*`, `Disable-*`,
   `Add-*`, `Remove-*`.
4. Live mutation tests must be opt-in with `-RunMutatingTests`.
5. Test workflows must use test-owned policies and test-owned associated
   objects.
6. Do not associate policies with pre-existing production LUNs, LUN groups,
   hosts, vStores, or file systems during validation.

## Domain Risks

- Low maximum IOPS or bandwidth values can throttle applications.
- Latency settings can change service behavior.
- Policy association is often more risky than policy creation.
- Disabling or removing an existing policy can remove intentional workload
  protection.

## Integrity Harness Behavior

The QoS workflow creates a SmartQoS policy for a test-owned LUN, updates and
toggles it, associates it with a test-owned LUN group, removes the association,
and cleans up the policy. It is gated by `QoS.Enabled`, `Lun.Enabled`,
`LunGroup.Enabled`, and the global mutation gates.
