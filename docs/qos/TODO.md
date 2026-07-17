# QoS TODO

## Current Focus

1. Keep SmartQoS docs aligned with implemented policy and association cmdlets.
2. Make throttling risks visible in every mutating example.
3. Clarify which live validation paths are LUN/LUN-group based today.

## High Priority

- Confirm live mutation coverage for file-system QoS attachment before
  documenting it as live-validated.
- Add examples for safe policy disable/remove cleanup after test-owned
  validation runs.

## Medium Priority

- Add guidance for choosing IOPS, bandwidth, latency, burst, and priority
  settings.
- Document parent/child policy behavior after more admin validation.

## Testing and Validation

- Unit tests cover QoS actions.
- Read-only integrity validates `Get-DMQosPolicy`.
- Mutating integrity validates policy creation, update, enable, disable,
  association with a test-owned LUN group, and cleanup when `QoS.Enabled`,
  `Lun.Enabled`, and `LunGroup.Enabled` are true.

## Documentation

- Keep QoS testing-status descriptions aligned with the harness vocabulary
  defined in [Tests/README.md](../../Tests/README.md) ("Status Meanings") and
  [docs/testing/integrity-tests.md](../testing/integrity-tests.md):
  - `NotRequested` — the gating switch (`-RunMutatingTests`) was not passed.
  - `NotConfigured` — the switch was passed but the config flag
    (`QoS.Enabled` / `Lun.Enabled` / `LunGroup.Enabled`) is not enabled.
  - `SkippedUnsafe` — the harness deliberately never exercises the action.
  - `Blocked` — the QoS domain was requested but a genuine test-owned
    prerequisite (e.g. a test-owned LUN group) did not materialize this run.
  QoS is not an opt-in performance domain, so an unmet QoS prerequisite in a
  requested mutating run surfaces as `Blocked` (not `NotRequested`).

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
