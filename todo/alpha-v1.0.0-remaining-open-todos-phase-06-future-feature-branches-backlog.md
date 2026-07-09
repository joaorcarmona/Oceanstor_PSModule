# alpha-v1.0.0 Remaining Open TODOs Phase 06 — Future Feature Branches Backlog

**Type:** Decision-only (backlog consolidation, no code changes).
**Live validation allowed:** No.
**Release-blocking:** No — every item here is explicitly out of scope for the alpha release across
all domain TODO files.

## Purpose

Consolidate every domain's "Future Feature Branches" table into one cross-domain backlog, so the
next feature-planning cycle has a single place to pull from instead of seven separate files.

## Source TODOs / evidence

- `docs/network/TODO.md` "## Future Feature Branches": routes/gateways (static route query/create/
  delete, not implemented), iSCSI portal/CHAP configuration cmdlets, NVMe-oF interface
  configuration cmdlets, per-port network performance/statistics getters, LLDP neighbor information
  getter. (Note: this table's header also contains the stale
  `alpha-v1.0.0-post-merge-phase-06-network-hardening-and-workflows.md` cross-reference — flagged
  for cleanup in Phase 01/07 of this plan, not fixed here.)
- `docs/replication-hypermetro/TODO.md` "## Future Feature Branches": remote LUN rescan
  (`remote_lun/scan_remote_lun`) and remote device link management; DR dashboards/reporting (pair
  health rollups via the existing report template system).
- `docs/qos/TODO.md` "## Future Feature Branches": `qos-filesystem-live-validation` (Medium effort
  — confirm file-system association safely), `qos-admin-cookbook` (Medium effort — needs
  operational examples).
- `docs/block-storage/TODO.md` future branches: block-storage-troubleshooting, protection-group-
  live-examples.
- `docs/file-storage/TODO.md` future branches: nas-service-config, quota-live-matrix,
  nas-troubleshooting-docs.
- `docs/snapshots/TODO.md` future branches: snapshot-policy-research, snapshot-restore-runbooks,
  snapshot-copy-cookbook.
- `docs/system-management/TODO.md`: LDAP/AD authentication implementation, Email/SMTP alerting
  implementation (both currently research-only, see Phase 05 of this plan), alarm/event lifecycle
  enhancements beyond the now-implemented read-only `Get-DMAlarmHistory`.

## Current repository evidence

- None of the above have a corresponding `Public/*.ps1` cmdlet in the current tree — confirmed by
  absence from `tokensave_todos` sweep and by each domain TODO file's own "not implemented" /
  "no active phase" language.

## Classification

Decision-only, backlog. Not release-blocking. No risk (nothing is implemented).

## Scope

- List every future-branch item in one consolidated table per domain, unchanged from source.
- Do not editorialize priority beyond what each domain file already states (Effort ratings are
  only present for QoS; other domains list items without an effort column — preserve that as-is
  rather than inventing estimates).

## Out of scope

- Implementing any of these items.
- Estimating effort for domains that did not already provide one.
- Creating a new branch, PR, or ticket for any of these — this is a backlog list only.

## Implementation tasks

None — this is a consolidation-only phase. Future work:

### Network
- Routes and gateways (static route query/create/delete)
- iSCSI portal / CHAP configuration cmdlets
- NVMe-oF interface configuration cmdlets
- Per-port network performance/statistics getters
- LLDP neighbor information getter
- Friendly-name enum aliases (`-BondPortType HostService`, `-AssociateObjectType EthernetPort`)
  with back-compat for numeric values (documented as deferred, not a "future branch" per se, but
  carried here since it is unimplemented and non-blocking)

### Replication / HyperMetro
- Remote LUN rescan (`remote_lun/scan_remote_lun`) and remote device link management
- DR dashboards/reporting (pair health rollups via existing report template system)

### QoS
- `qos-filesystem-live-validation` (Medium)
- `qos-admin-cookbook` (Medium)

### Block Storage
- block-storage-troubleshooting
- protection-group-live-examples

### File Storage / NAS
- nas-service-config
- quota-live-matrix
- nas-troubleshooting-docs

### Snapshots
- snapshot-policy-research
- snapshot-restore-runbooks
- snapshot-copy-cookbook

### System Management
- LDAP/AD authentication implementation (research note exists;
  `docs/system-management/ldap-ad-smtp-alerting-research.md`)
- Email/SMTP alerting implementation (same research note)
- Alarm/event lifecycle enhancements beyond `Get-DMAlarmHistory`. Note these are deferred with
  specific safety blockers rather than simply "future" (see Phase 05): **alarm acknowledge** has no
  documented endpoint (rejected), and **alarm clear** already ships as the `Clear-DMAlarm` cmdlet —
  only its *live validation* is deferred pending a safe test-alarm generator.

## Files likely to inspect

- `docs/network/TODO.md`, `docs/replication-hypermetro/TODO.md`, `docs/qos/TODO.md`,
  `docs/block-storage/TODO.md`, `docs/file-storage/TODO.md`, `docs/snapshots/TODO.md`,
  `docs/system-management/TODO.md`

## Files likely to modify

- None in this task.

## Safety considerations

- None — no implementation occurs in this phase.

## Testing strategy

- N/A.

## Verification commands

```powershell
git diff --check
git status --short
```

## Dependencies

- None.

## Completion criteria

- This consolidated backlog is complete once committed. Individual items graduate out of this file
  only when a future feature-planning task picks one up and creates its own dedicated phase.

## Risks / notes

- No risk — pure backlog consolidation.
