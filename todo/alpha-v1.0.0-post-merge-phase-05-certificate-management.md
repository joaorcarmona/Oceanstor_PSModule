# alpha-v1.0.0 Post-Merge Phase 05 — Certificate Management (Research + Read-Only First)

## Purpose

Turn the documented certificate-management gap into shipped capability, strictly in two
stages: (1) REST research and a read-only certificate inventory getter; (2) only after
schema confirmation and a lab-safe procedure exists, the mutating import/export/remove
surface — which stays `SkippedUnsafe` in live validation regardless.

## Source TODOs / evidence

- `docs/system-management/TODO.md` § High Priority 2 "Certificate management":
  "Research OceanStor Dorado 6.1.6 REST certificate endpoints. Identify safe, read-only
  certificate inventory first. Implement cmdlets only [once] REST schema confirmed:
  `Get-DMCertificate`, `Import-DMCertificate`, `Export-DMCertificate`,
  `Remove-DMCertificate`."
- `docs/system-management/certificates.md` — "**Status: Not implemented / gap / planned**";
  mutating workflow belongs in a lab-only workflow "or permanently in the
  `SkippedUnsafe` list".
- `docs/system-management/safety-and-live-validation.md` — `CertificateMutation` category:
  "Do not run live unless explicitly lab-safe (not implemented today)".
- Verified against code: no `*Certificate*` file exists under `POSH-Oceanstor/Public/`.

Deduplication decision:
Certificate work appears in both the system-management TODO and the safety doc; it is
owned entirely by this phase. Phase 04 (SystemManagement workflow) explicitly excludes
certificates; Phase 10 only re-checks that `certificates.md` status text matches whatever
this phase ships.

## Scope

Stage A — research and read-only (this phase's committed scope):
- [Safety review] Extract and document every certificate-related endpoint from
  `OceanStor Dorado 6.1.6 REST Interface Reference.md` (inventory/query, import, export,
  activate/replace, delete), including which certificate stores exist (management UI,
  syslog TLS, LDAP TLS, etc.) and response schemas.
- [Code] `Get-DMCertificate`: read-only inventory (subject, issuer, validity dates,
  fingerprint, store/usage), typed output class (string-form `[OutputType(...)]`),
  pagination if the endpoint is list-shaped.
- [Tests] Unit tests with mocked responses matching the documented schema;
  registration in `Tests/ModuleCoverage.psd1`; entry in
  `Tests/Integration/Private/ReadValidation.ps1` (read-only, safe for live runs).
- [Docs-only] Rewrite `docs/system-management/certificates.md` from "gap" page to a real
  topic page for the getter; keep mutation clearly marked unimplemented/planned.

Stage B — mutating surface (design in this phase, implement only if Stage A confirms
schema and a lab procedure is approved):
- [Code] `Import-DMCertificate` / `Export-DMCertificate` / `Remove-DMCertificate` with
  `SupportsShouldProcess`, `ConfirmImpact = 'High'`.
- [Live-validation planning] These are permanently `SkippedUnsafe` in the harness;
  replacing a live management certificate requires a dedicated human-run lab procedure
  with console-recovery access, never automation.

## Out of scope

- Any automated live certificate mutation, ever, on the shared lab array
  (risk: severing HTTPS management access — the connection the module itself uses).
- CA / CSR generation workflows unless the REST reference documents them.

## Implementation tasks

- [Safety review] Endpoint research memo (internal, `.archived-commands/`), including
  whether export returns private keys (if so: never log, never write to disk unprompted).
- [Code] Implement `Get-DMCertificate` + class + format view.
- [Tests] Unit tests; `-WhatIf` tests for Stage B mutators if built.
- [Docs-only] Update `certificates.md`, `docs/system-management/README.md` status cell,
  and TODO.
- [Live-validation planning] Written lab-only replacement procedure (prereqs: out-of-band
  access, current cert backup/export, rollback steps) — documentation only.

## Files likely to inspect

- `OceanStor Dorado 6.1.6 REST Interface Reference.md`
- Existing getter+class patterns (`Get-DMdnsServer` post-Phase-03, `Get-DMFailoverGroup`)

## Files likely to modify

- New `POSH-Oceanstor/Public/Get-DMCertificate.ps1` (+ Stage B cmdlets if approved)
- New `POSH-Oceanstor/Private/class-OceanStorCertificate.ps1`
- `POSH-Oceanstor.psd1` (`FunctionsToExport`), `Tests/ModuleCoverage.psd1`
- `Tests/Integration/Private/ReadValidation.ps1` + dot-source whitelist if new Private
  helpers are added
- `docs/system-management/certificates.md`, `README.md`, `TODO.md`

## Safety considerations

- Read-only inventory only in live validation. Certificate mutation is in the "never
  mutate" list for validation runs — no exception, even test-owned, because certificate
  stores are global state with management-access blast radius.
- Never print certificate private material or credentials; sanitized examples use
  `$storageIP = 'StorageIP'`.

## Testing strategy

1. Unit tests from documented response schemas (no live dependency).
2. Full unit suite + manifest test after export list changes.
3. Read-only live coverage arrives automatically via `ReadValidation.ps1` in the next
   scheduled live run.

## Verification commands

```powershell
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
Get-Command -Module POSH-Oceanstor
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
```

## Dependencies

- Phase 01. Benefits from Phase 02 (`NotRequested` reporting for Stage B mutators).

## Completion criteria

- `Get-DMCertificate` shipped with unit tests, live read registration, and a real topic
  page; Stage B either shipped behind `ShouldProcess` + permanent `SkippedUnsafe`, or a
  written decision to defer with reasons.

## Risks / notes

- The TODO's branch table rates this Fable/Opus-High: REST research + risk management.
- If the REST reference lacks certificate endpoints for 6.1.6, record that finding and
  close the TODO item as "blocked on vendor documentation" rather than guessing at
  undocumented endpoints.
