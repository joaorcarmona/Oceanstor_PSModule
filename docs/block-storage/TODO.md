# Block Storage TODO

## Current Focus

1. Keep block-storage docs aligned with the existing public cmdlet surface.
2. Preserve test-owned mutation rules in every future workflow.
3. Improve examples as storage-admin workflows are validated against lab arrays.

## High Priority

- Document any future array-version differences for LUN creation, expansion,
  and removal behavior.
- Keep direct mapping and mapping-view examples in sync with cmdlet parameter
  names.

## Medium Priority

- Expand protection-group guidance after more live validation is available.

## Testing and Validation

- Unit tests exist for representative LUN, host, LUN-group, mapping,
  initiator, protection, and performance wrapper behavior.
- Read-only integrity covers getters and lookup variants.
- Mutating integrity requires `-RunMutatingTests` and
  `AllowMutatingTests = $true`.
- Individual workflows also require config gates such as `Lun.Enabled`,
  `LunGroup.Enabled`, `Host.Enabled`, `Mapping.Enabled`,
  `Initiators.Enabled`, `Protection.Enabled`, and
  `HyperCDPSchedule.Enabled`.
- Live validation 2026-07-09 (run ID 20260709033729): the HyperCDP schedule
  lifecycle passed end-to-end on a test-owned schedule (create, get by
  ID/name, set, LUN associate/dissociate, enable/disable, remove by captured
  ID). Two harness fixes were required: the HyperCDP private helpers were
  missing from the integrity runner's dot-source whitelist (live-only
  failure), and the generated schedule name exceeded the array's 31-character
  cap (suffix shortened to `cdp`). The storage-pool rename round-trip also
  passed live with the original name verified restored.

## Documentation

- Keep this folder and `docs/testing/` aligned when workflows or status
  vocabulary change.
- Do not link public docs to archived validation notes.

## Future Feature Branches

| Branch | Effort | Reason |
|---|---:|---|
| block-storage-troubleshooting | Medium | Broader admin cookbook (the mapped-LUN-removal page landed in Phase 05) |
| protection-group-live-examples | Medium | Needs careful lab confirmation |

## Not Planned / Unsafe by Default

- Broad cleanup of LUNs, mappings, initiators, or host objects by name pattern.
- Removal of pre-existing production mappings or initiators in automated tests.
- Live destructive examples without `-WhatIf` or an explicit test-owned object.

## Notes for Contributors

- Read [safety-and-live-validation.md](safety-and-live-validation.md).
- Use test-owned resources and cleanup by captured ID or exact captured name.
- Never broaden cleanup after a failure.
