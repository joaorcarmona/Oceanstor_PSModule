# File Storage TODO

## Current Focus

1. Keep NAS docs aligned with implemented file-system, share, dTree, and quota cmdlets.
2. Keep examples safe and test-owned.
3. Record service-configuration gaps without implying support.

## Recently Completed

- Public docs were added for file systems, NFS/CIFS shares, NFS clients,
  dTrees, quotas, NAS service gaps, and safety.
- Existing integrity workflows already include test-owned NAS lifecycle
  coverage when configured.

## High Priority

- Add deeper examples for multi-vStore NAS environments.
- Document CIFS prerequisites once AD/domain/CIFS service cmdlets exist.
- Expand quota examples after more live validation across quota types.

## Medium Priority

- Add operational notes for file-system capacity growth and rollback choices.
- Add examples for private NFS shares and dTree-scoped shares.
- Add a troubleshooting page for share lookup and permission failures.

## Low Priority / Polish

- Add compact inventory views for file systems, shares, clients, and quotas.
- Add diagrams for file system, dTree, share, client, and quota relationships.

## Testing and Validation

- Unit tests cover file-system creation/update/removal, NFS/CIFS share
  behavior, dTree creation/removal/update, file-system snapshots, and quotas.
- Read-only integrity validates `Get-DMFileSystem`, `Get-DMShare`,
  `Get-DMnfsFileClient`, `Get-DMFileSystemSnapshot`, and `Get-DMQuota`.
- Mutating integrity requires `-RunMutatingTests`, `AllowMutatingTests`,
  `Nas.Enabled`, and feature gates such as `Nas.EnableDTree`,
  `Nas.EnableFileSystemSnapshot`, `Nas.EnableNfs`, `Nas.EnableCifs`, and
  `Nas.EnableQuota`.

## Documentation

- Keep this folder and `docs/testing/` aligned when NAS workflow gates change.
- Do not publish raw validation or gap-analysis reports.

## Future Feature Branches

| Branch | Effort | Reason |
|---|---:|---|
| nas-service-config | High | AD/LDAP/CIFS service setup is operationally sensitive |
| quota-live-matrix | Medium | Needs careful array-version validation |
| nas-troubleshooting-docs | Medium | Admin workflow polish |

## Not Planned / Unsafe by Default

- Deleting pre-existing file systems or shares in automated workflows.
- Broad cleanup of NFS clients, shares, quotas, or dTrees by name pattern.
- Changing production export/client access from tests.

## Notes for Contributors

- Use test-owned resources only in live workflows.
- Cleanup by captured ID or exact captured path/name.
- Never modify or remove an object that existed before the run.
