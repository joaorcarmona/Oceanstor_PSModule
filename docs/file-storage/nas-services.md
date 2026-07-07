# NAS Services

## Scope

This page tracks NAS service configuration in the context of file-storage
documentation.

## Cmdlets

| Cmdlet | Purpose | Read/Mutate | Safety |
|---|---|---|---|
| None confirmed | CIFS/SMB service, AD, LDAP, DNS-for-NAS, and NFS service configuration are not implemented in this domain | - | Do not document as available |

## Common Workflows

No public workflow is documented because no service-configuration cmdlets were
found for this domain.

## Examples

No examples are provided for unimplemented service configuration.

## Safety Notes

NAS service configuration is authentication and access sensitive. Future
cmdlets should have unit tests, `SupportsShouldProcess` for mutations, and
lab-safe live validation rules.

## Integrity Test Coverage

No dedicated live workflow exists for NAS service configuration.

## Known Gaps

- CIFS/SMB service configuration is not implemented.
- AD and LDAP join/configuration cmdlets are not implemented.
- NFS service-level configuration is not implemented.
- Share and client object cmdlets are implemented separately.

## Related Files

- `docs/file-storage/cifs-shares.md`
- `docs/file-storage/nfs-shares.md`
- `docs/file-storage/nfs-clients.md`
