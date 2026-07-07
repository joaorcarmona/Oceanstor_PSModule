# File Storage Safety and Live Validation

NAS commands can interrupt file access. Treat every create, set, rename, or
remove action as storage-impacting until proven otherwise.

## Rules

1. Read-only inventory commands are generally safe.
2. Mutating commands require explicit user intent.
3. Live mutation tests must be opt-in with `-RunMutatingTests`.
4. Workflows must use test-owned resources only.
5. Cleanup must use captured ID, exact path, or exact captured name only.
6. Do not delete or modify pre-existing file systems, shares, NFS clients,
   dTrees, or quotas.
7. Use `-WhatIf` when learning mutators.
8. Avoid destructive operations on shared or production arrays.

## Domain Risks

- `Remove-DMFileSystem` can delete NAS data.
- Share removal can break client access.
- NFS client permission changes can grant or remove access.
- dTree changes can affect namespace and quota structure.
- Quota changes can block writes or alter capacity enforcement.

## Integrity Harness Behavior

The NAS mutation workflow creates a test-owned file system, optionally expands
and renames it, then optionally validates dTree, NFS, CIFS, file-system
snapshot, and quota operations according to config gates. Cleanup is limited
to objects created by that run.
