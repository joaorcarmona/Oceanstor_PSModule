# Certificates System Management

> **Status: Partial — read-only inventory implemented (`Get-DMCertificate`).
> Certificate mutation is not implemented and is permanently unsafe for
> automated live validation.**

## Scope

Management of array certificates. The array models certificates as one slot
per certificate type (HTTPS, DeviceManager, Syslog, NTP, Call Home, SSO,
Email, HyperMetro, domain authentication, and others), optionally per vStore.

Implemented today: **read-only inventory**. Importing, exporting, replacing,
activating, and deleting certificates are **not implemented** (see
[Mutation status](#mutation-status)).

## Cmdlets

| Cmdlet | Action | Class |
|---|---|---|
| `Get-DMCertificate` | List certificate slots (subject, issuer, validity, fingerprint, type, status) | `ReadOnlySystemManagement` |

Typed output: `OceanStorCertificate`
(`POSH-Oceanstor/Private/class-OceanStorCertificate.ps1`). One object per
certificate-type slot; slots without an installed certificate are returned
with `Status = 'Absent'` and empty subject/fingerprint/date values. The
endpoint (and therefore the cmdlet) exposes no private-key material.

Key properties: `CertificateType`, `TypeId`, `Status`
(`Valid`/`Invalid`/`Absent`), `Subject`, `Issuer`, `ValidTo`, `Fingerprint`,
`SerialNumber`, `SignatureAlgorithm`, `KeyAlgorithm`, `KeyLength`,
`ExpireWarningDays`, auto-update flags, and the CA-side counterparts
(`CAStatus`, `CASubject`, `CAIssuer`, `CAValidTo`, `CAFingerprint`, ...).

## Common Workflows

Certificate expiry review across the array, and pre-change inventory capture
before any (manual) certificate maintenance.

## Examples

```powershell
$storageIP = 'StorageIP'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
$storage = Connect-deviceManager -Hostname $storageIP -Credential $cred -PassThru

# Full inventory, one row per certificate slot
Get-DMCertificate

# Only installed, valid certificates
Get-DMCertificate | Where-Object Status -eq 'Valid'

# Certificates expiring within 90 days
Get-DMCertificate | Where-Object { $_.ValidTo -and $_.ValidTo -lt (Get-Date).AddDays(90) }

# vStore-scoped inventory (documented vStore scenario only)
Get-DMCertificate -VstoreId '3'
```

## Mutation status

`Import-DMCertificate`, `Export-DMCertificate`, and `Remove-DMCertificate`
are **not implemented**:

- **Import — blocked on vendor documentation.** The 6.1.6 REST reference
  documents certificate *activation* of a file already present on the array,
  but not the certificate upload step itself. Implementing against a guessed
  upload interface is prohibited.
- **Export — deferred.** The documented download endpoint is path-addressed
  with unspecified path semantics; whether private-key files are retrievable
  is not stated, so it is treated as a private-material risk.
- **Remove/replace/activate — deferred pending an approved lab-safe
  procedure.** The endpoints are documented, but no lab procedure has been
  approved.

If any of these are ever implemented, they will use `SupportsShouldProcess`
with `ConfirmImpact = 'High'` and will remain **permanently `SkippedUnsafe`**
in live validation.

## Safety Notes

- **Certificate mutation can sever HTTPS management access** — including the
  very session POSH-Oceanstor uses. Replacing or deleting the
  DeviceManager/HTTPS certificate is classified `CertificateMutation` and
  must never run outside a dedicated, human-supervised lab procedure with
  out-of-band recovery access.
- `Get-DMCertificate` is safe: GET-only, no private material in the response
  schema (subjects, issuers, fingerprints, serials, algorithms, dates only).
- Live validation runs **only** the read-only inventory; certificate
  mutation is permanently in the `SkippedUnsafe` category, with no
  test-owned exception — certificate slots are global array state.

## Integrity Test Coverage

- Unit tests: `Tests/Unit/Public/Get-DMCertificate.Tests.ps1` (mocked
  responses matching the documented schema, empty-inventory handling,
  placeholder normalization, display-set and hidden-`Raw` checks).
- Live read validation: registered in
  `Tests/Integration/Private/ReadValidation.ps1` (`Get-DMCertificate`,
  expected type `OceanStorCertificate`; tolerates empty inventory).
- Mutation: nothing registered, by design — see [Safety Notes](#safety-notes).

## Known Gaps

- No mutation surface (import/export/remove/activate) — see
  [Mutation status](#mutation-status) for the per-cmdlet reasons.
- CA/CSR workflows: CSR generation is not documented in the 6.1.6 REST
  reference and is out of scope. CRL and CA-server endpoints exist but are
  not implemented.

## Related Files

- `POSH-Oceanstor/Public/Get-DMCertificate.ps1`
- `POSH-Oceanstor/Private/class-OceanStorCertificate.ps1`
- `Tests/Unit/Public/Get-DMCertificate.Tests.ps1`
- `Tests/Integration/Private/ReadValidation.ps1`
- [safety-and-live-validation.md](safety-and-live-validation.md)
- `POSH-Oceanstor/Public/Connect-deviceManager.ps1` (`-SkipCertificateCheck`)
