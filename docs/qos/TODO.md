# QoS TODO

## Current Focus

1. Keep SmartQoS docs aligned with implemented policy and association cmdlets.
2. Make throttling risks visible in every mutating example.
3. Clarify which live validation paths are LUN/LUN-group based today.

## Recently Completed

- Public docs were added for SmartQoS policy lifecycle, LUN QoS, file-system
  QoS, and safety.
- Existing integrity workflow validates test-owned SmartQoS when dependencies
  are enabled.

## High Priority

- Confirm live mutation coverage for file-system QoS attachment before
  documenting it as live-validated.
- Add examples for safe policy disable/remove cleanup after test-owned
  validation runs.

## Medium Priority

- Add guidance for choosing IOPS, bandwidth, latency, burst, and priority
  settings.
- Document parent/child policy behavior after more admin validation.

## Low Priority / Polish

- Add compact reporting examples for policy inventory.
- Add a small glossary for SmartQoS API concepts.

## Testing and Validation

- Unit tests cover QoS actions.
- Read-only integrity validates `Get-DMQosPolicy`.
- Mutating integrity validates policy creation, update, enable, disable,
  association with a test-owned LUN group, and cleanup when `QoS.Enabled`,
  `Lun.Enabled`, and `LunGroup.Enabled` are true.

## Documentation

- Keep docs/testing status descriptions aligned with `NotConfigured` and
  `Blocked` behavior for missing QoS prerequisites.

## Future Feature Branches

| Branch | Effort | Reason |
|---|---:|---|
| qos-filesystem-live-validation | Medium | Confirm file-system association safely |
| qos-admin-cookbook | Medium | Needs operational examples |

## Not Planned / Unsafe by Default

- Throttling existing production workloads from automated tests.
- Applying broad QoS associations by name pattern.

## Notes for Contributors

- Treat QoS as production-impacting even when no data is deleted.
- Use test-owned LUNs, LUN groups, and policies for live validation.
