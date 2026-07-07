# Certificates System Management

> **Status: Not implemented / gap / planned**

## Scope

Management of array certificates: querying installed certificates, importing
CA/management certificates, exporting certificates, replacing the
DeviceManager management certificate, and deleting certificates.

**None of this is implemented in POSH-Oceanstor today.** No `*Certificate*`
cmdlets exist in `POSH-Oceanstor/Public/`. This document records the gap and
the design expectations so the eventual implementation lands consistently.

## Cmdlets

None. Proposed surface (names follow existing module conventions — do not
treat these as available commands):

| Proposed cmdlet | Action | Class |
|---|---|---|
| `Get-DMCertificate` | List installed certificates | `ReadOnlySystemManagement` |
| `Import-DMCertificate` | Import a certificate | `CertificateMutation` |
| `Export-DMCertificate` | Export a certificate to a local file | `LocalFileOnly` |
| `Remove-DMCertificate` | Delete a certificate | `CertificateMutation` |

## Common Workflows

Not available. Today, certificate operations must be performed in the
DeviceManager UI or via direct REST calls.

## Examples

None — no cmdlets exist. The only certificate-adjacent behavior in the module
is the `-SkipCertificateCheck` switch on `Connect-deviceManager`, which
relaxes TLS validation for lab arrays with self-signed certificates.

## Safety Notes

For the future implementation:

- Replacing or deleting the management certificate can sever every HTTPS
  management session, including the one performing the change. Classify as
  `CertificateMutation`; never run live outside a dedicated lab.
- `Get-DMCertificate` and export-to-file operations are safe
  (`ReadOnlySystemManagement` / `LocalFileOnly`).
- Live validation of import/remove should only ever target a test-owned,
  non-active certificate object, if the API supports one.

## Integrity Test Coverage

Not applicable — nothing to test. When implemented, the getter belongs in
`ReadValidation.ps1`, and the mutators belong in a default-off, explicitly
lab-only workflow (or permanently in the `SkippedUnsafe` list).

## Known Gaps

- Entire domain is an `UnsupportedFeatureGap`. The repository-level gap
  analysis (`.archived-commands/GAP_Analysis.md`) names certificate
  management as the remaining notable array-configuration gap; all four
  reference vendor modules (Pure, NetApp, Dell/EMC, HPE) expose certificate
  management.

## Related Files

- `.archived-commands/GAP_Analysis.md` (source gap analysis)
- `Oceanstor_PSModule_TODO.md` (module TODO list)
- `POSH-Oceanstor/Public/Connect-deviceManager.ps1` (`-SkipCertificateCheck`)
