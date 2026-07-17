# Snapshots TODO

## Current Focus

1. Document implemented LUN, file-system, consistency-group, copy, and
   HyperCDP schedule cmdlets accurately.
2. Keep restore and deletion warnings prominent.
3. Track live integrity gaps without publishing raw validation reports.

## High Priority

- `Set-DMHyperCDPSchedule` (`PUT SNAPSHOT_SCHEDULE/{id}`) omitted the Mandatory `ID`
  body field — **root-caused + fixed 2026-07-17 (static analysis).** The modify interface
  (REST reference §4.9.12.3.3) marks **`ID` Mandatory** in the body; every other field is
  Optional/Conditional. `ConvertTo-DMHyperCDPSchedulePayload` never emits `ID`, so the
  cmdlet previously sent it only in the URL path — the same `50331651` omission pattern as
  the `Set-DMvLan`/SNMP-trap fixes. `Set-DMHyperCDPSchedule` now echoes
  `$body.ID = $schedule.Id` before the PUT; unit assertion added to
  `Tests/Unit/Public/HyperCDPSchedule.Tests.ps1` ("modifies a schedule by name").
  **Live-confirmed 2026-07-17 against a V600R005C27 lab array (10.10.10.24): a throwaway
  HyperCDP schedule was created, its description modified via `Set-DMHyperCDPSchedule`
  (accepted — no `50331651`), read back, and removed by captured ID; array state restored,
  no leftovers.**
- Confirm whether additional snapshot policy or schedule APIs should be
  implemented beyond HyperCDP schedules.
- Add deeper restore runbooks for isolated lab use.

## Medium Priority

- Expand clone/copy workflow examples once operational semantics are confirmed
  for each supported array version.
- Document snapshot retention behavior where the API exposes it.

## Low Priority / Polish

- Add compact snapshot inventory reports for admins.
- Add relationship diagrams for protection groups and consistency groups.

## Testing and Validation

- Unit tests cover LUN snapshots, LUN snapshot copies, file-system snapshots,
  snapshot actions, consistency groups, and HyperCDP schedules.
- Read-only integrity validates `Get-DMLunSnapshot`,
  `Get-DMFileSystemSnapshot`, `Get-DMSnapshotConsistencyGroup`, and
  `Get-DMHyperCDPSchedule`.
- Mutating integrity requires `-RunMutatingTests`, `AllowMutatingTests`, and
  feature gates such as `Lun.Enabled`, `Nas.EnableFileSystemSnapshot`,
  `Protection.Enabled`, and `HyperCDPSchedule.Enabled`.

## Documentation

- Keep safety guidance aligned with `docs/testing/live-validation-safety.md`.

## Future Feature Branches

| Branch | Effort | Reason |
|---|---:|---|
| snapshot-policy-research | Medium | Confirm unsupported policy APIs |
| snapshot-restore-runbooks | High | Restore is high-risk |
| snapshot-copy-cookbook | Medium | Needs lab confirmation |

## Not Planned / Unsafe by Default

- Restoring or deleting pre-existing snapshots in automated tests.
- Broad cleanup of snapshots by name pattern.
- Production rollback examples without explicit isolation warnings.

## Notes for Contributors

- Cleanup test-owned snapshots only.
- Restore workflows must target only resources created by the same run.
- Do not broaden cleanup if a snapshot delete fails.
