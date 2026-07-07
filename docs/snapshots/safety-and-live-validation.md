# Snapshot Safety and Live Validation

Snapshot commands manage recovery points and rollback behavior. Reads are safe;
deletes and restores are not casual operations.

## Rules

1. Read-only inventory commands are generally safe.
2. Mutating commands require explicit user intent.
3. Live mutation tests must be opt-in with `-RunMutatingTests`.
4. Test workflows must use test-owned LUNs, file systems, protection groups,
   consistency groups, and snapshots.
5. Cleanup must use captured IDs or exact captured names only.
6. Do not delete or restore pre-existing snapshots.
7. Use `-WhatIf` when learning mutators.
8. Avoid destructive operations on shared or production arrays.

## Domain Risks

- Snapshot deletion removes recovery points.
- Snapshot restore/rollback can overwrite live data.
- Snapshot copy creation can consume capacity.
- Restart/activate actions can change snapshot state.
- HyperCDP schedule changes can create or retain unexpected recovery points.

## Integrity Harness Behavior

The harness creates snapshots only under test-owned LUNs or file systems.
Snapshot consistency group rollback targets the LUN created by the same run.
HyperCDP schedule validation is disabled by default and must be explicitly
enabled in config.
