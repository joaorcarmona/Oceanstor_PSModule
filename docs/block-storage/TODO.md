# Block Storage TODO

## Current Focus

1. Keep block-storage docs aligned with the existing public cmdlet surface.
2. Preserve test-owned mutation rules in every future workflow.
3. Improve examples as storage-admin workflows are validated against lab arrays.

## Recently Completed

- Phase 08 docs polish: relationship diagram (host / host group / LUN group /
  mapping view / port group) and sample `Select-Object` inventory views added to
  [mapping-views.md](mapping-views.md); the mapped-LUN-removal troubleshooting
  page is now listed in the README documentation map. Legacy-wrapper migration
  note and troubleshooting page were already shipped in Phase 05.
- Public docs were added for block storage, including LUNs, pools, hosts,
  initiators, LUN groups, mapping views, and protection groups.
- Existing integrity workflows already cover test-owned LUN, host, mapping,
  initiator, LUN-group, protection, QoS dependency, and HyperCDP schedule
  scenarios when configured.
- Phase 08: `Set-DMMappingView` / `Rename-DMMappingView` added (name/description
  labels only, `PUT /mappingview/{id}`; associations unchanged). The mapping
  workflow now includes a test-owned `Set-DMMappingView` description read-back.
  Storage-pool **rename** shipped as `Rename-DMstoragePool` (NAME label only,
  `PUT storagepool/{id}`, `ConfirmImpact='High'`), validated live as a reversible
  round-trip (rename → read-back → rename to original → verify) on a pre-existing
  pool. Storage-pool **Set** (description / threshold / container) and
  create/delete/resize remain deferred (documented for Dorado 6.1.6 only, high
  blast radius, per-generation behavior unconfirmed). Initiator action methods
  were rejected (immutable WWN/IQN identity, command-only for `ShouldProcess`
  clarity). NAS-child modification (`Set-DMCifsShare`, `Set-DMdTree`,
  `Set-DMnfsShare`, `Set-DMnfsClient`) already shipped.
- Phase 05: block-storage documentation carry-over closed —
  vStore-scoped mapping (`-VstoreId`) guidance and a legacy-wrapper migration
  note added to [mapping-views.md](mapping-views.md), and a dedicated
  [mapped-lun-removal-troubleshooting.md](mapped-lun-removal-troubleshooting.md)
  page added.

## High Priority

- Document any future array-version differences for LUN creation, expansion,
  and removal behavior.
- Keep direct mapping and mapping-view examples in sync with cmdlet parameter
  names.

## Medium Priority

- Expand protection-group guidance after more live validation is available.

## Low Priority / Polish

- _Done (Phase 08)._ Relationship diagram and sample `Select-Object` inventory
  views added to [mapping-views.md](mapping-views.md).

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
