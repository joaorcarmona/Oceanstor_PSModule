# Oceanstor_PSModule Development Roadmap & TODO

This document is the single backlog for planned work, design decisions, improvements, and completed validation notes for `Oceanstor_PSModule`.

Detailed audit findings live in `ANALYSIS.md`. Release-facing summaries live in `RELEASE_NOTES.md`.

---

## Active Backlog

### Command Coverage Decisions

- [ ] Decide whether mapping views need `Set-DMMappingView`, `Rename-DMMappingView`, and a matching object `Rename()` method.
- [ ] Decide whether storage pools need supported Set/Rename commands and object methods; confirm the Huawei API behavior for each supported device generation first.
- [ ] Decide which NAS children need modification commands: dTrees, CIFS shares, NFS shares, and NFS clients currently support only their existing create/read/delete surface.
- [ ] Decide whether initiator objects need action methods or should remain command-only objects.
- [ ] Decide whether network objects (LIFs, VLANs, physical ports, bonds, and vStores) should remain read-only or gain supported mutation commands.

### Native Pipeline & Context Architecture

- [ ] **Implement Complete Pipeline Support**
  - Add `ValueFromPipeline` and `ValueFromPipelineByPropertyName` attributes to core parameters inside targeting commands.
  - Structure cmdlets with proper `begin {}`, `process {}`, and `end {}` blocks to prevent multi-object arrays from flattening or dropping records.
  - Rely on pipeline processing or array-bound parameters to handle multi-object output naturally, now that endpoint nouns are singular (see Completed).

### Resilient REST API Integration

- [ ] **Audit `Get-DM*` Commands for Missing Pagination**
  - Only `Get-DMlun`, `Get-DMFileSystem`, and `Get-DMLunSnapshot` use `Private/Invoke-DMPagedRequest.ps1`; confirmed via a live 1000+ LUN test that this pagination path had two real bugs (wrong range separator, off-by-one end boundary — both fixed and confirmed against `OceanStor Dorado 6.1.6 REST Interface Reference.md`, which documents `range=[start-end]` with an **exclusive** end index and recommends querying a maximum of 150 records per unpaged request).
  - The other ~35 list-returning `Get-DM*` commands (`Get-DMhost`, `Get-DMnfsFileClient`, `Get-DMShare`, `Get-DMPortGroup`, `Get-DMdisk`, `Get-DMHostInitiator`, etc.) call `Invoke-DeviceManager` directly for a single unpaged request and have never been tested past ~150 records — each is a candidate for the same silent-truncation failure mode (no error, just an incomplete list) that pagination exists to prevent.
  - Bulk-create test data for a few more resource types (hosts, NFS clients, port groups) to check whether their unpaged responses actually truncate on this array before deciding scope: this may be an isolated LUN/FileSystem/Snapshot-family quirk, or evidence of a module-wide gap needing `Invoke-DMPagedRequest` added more broadly.

### Testing, CI/CD, & Supply Chain Security

- [ ] **Develop Robust API Mocking**
  - Build comprehensive `Mock Invoke-RestMethod` templates that mimic real Huawei OceanStor v6 responses.
  - Keep code-path validation isolated and safe without requiring a physical SAN connection.
- [ ] **Automate Release Pipeline to PowerShell Gallery**
  - Design a continuous deployment workflow that signs, packages, and publishes a validated versioned module to the PowerShell Gallery on GitHub Release tags.

---

## Completed / Validated

### Correctness

- [x] ~~Add integration checks for actual LUN and file-system capacity expansion.~~ `Set-DMLun -Capacity` and `Set-DMFileSystem -Capacity` are exercised in the mutation workflows (`Lun.ps1`, `Nas.ps1`), with read-back verification that `RealCapacity` matches the expanded value. A unit test also covers the case where capacity expansion is skipped after a failed property modification.
- [x] ~~Verify Set operations by reading back the changed description/properties, not only the renamed identity.~~ `Set-DMHost`, `Set-DMHostGroup`, `Set-DMLunGroup`, `Set-DMPortGroup`, `Set-DMLun`, and `Set-DMFileSystem` each re-fetch the object after modification and assert the description text persisted.
- [x] ~~Add direct tests for mutation ownership transfer after rename, including cleanup after a read-back or dependent-operation failure.~~ `Tests/Unit/Private/ValidationHelpers.Tests.ps1` directly tests `Update-TestOwnedResourceIdentity` and `Invoke-OwnedRemoval`, including an end-to-end scenario where cleanup still targets the renamed identity after a read-back failure.

### CI and Cross-Platform

- [x] ~~Add Ubuntu and macOS to the CI test matrix.~~ Fixed by removing the `Get-DMSystem` call from inside the `OceanstorSession` constructor. `Connect-deviceManager` now resolves `Version` after construction, where Pester mocks apply normally. `windows-latest`, `ubuntu-latest`, and `macos-latest` all pass in the Pester matrix.

### Consistency and Maintainability

- [x] ~~Enforce strict PascalCase/lowercase standards.~~ Keywords (`if`, `else`, `foreach`, `try`, `catch`) and logical constants (`$true`, `$false`) are lowercase across all `.psm1` and helper script files.
- [x] ~~Expand unit coverage for public commands that had no direct tests.~~ `Disconnect-deviceManager`, `New-DMnfsShare`, `New-DMnfsClient`, and `Set-DMdnsServer` have dedicated tests. All 127 public commands are referenced in at least one unit test file.
- [x] ~~Define a consistent minimum object-method surface, such as `Rename()`, `Delete()`, and relationship helpers, for mutable returned objects.~~ `Delete()` was added to all mutable classes that lacked it, including LUN, file system, host, group, mapping view, NAS share, and dTree classes. Each method is covered by the corresponding class tests.
- [x] ~~Generate command/object inventory during CI and fail when a new public command or class is absent from maintained coverage metadata.~~ `Tests/ModuleCoverage.psd1` records all class names. `Tests/Unit/Private/ModuleInventory.Tests.ps1` cross-checks every `Public/*.ps1` file against `FunctionsToExport` and every `Private/class-*.ps1` file against `ModuleCoverage.psd1`.
- [x] ~~Enforce explicit export controls.~~ `POSH-Oceanstor.psd1` explicitly lists all 127 public commands in `FunctionsToExport`; the list matches `POSH-Oceanstor/Public/*.ps1`, and `Test-ModuleManifest` validates the manifest.
- [x] ~~Standardize noun cardinality.~~ Done in v0.9.4: 30 plural-noun getter commands were renamed to their singular canonical forms (`Get-DMLuns` → `Get-DMlun`, `Get-DMHosts` → `Get-DMhost`, etc.), with 30 backward-compatibility aliases exported in `POSH-Oceanstor.psd1` (`AliasesToExport`) so existing scripts keep working. See `RELEASE_NOTES.md` v0.9.4.
- [x] ~~Implement Module/Script-Scoped Session Fallback.~~ `POSH-Oceanstor.psm1` now initializes a module-private `$script:CurrentOceanstorSession` variable. `Connect-deviceManager` caches successful sessions into it (and clears/replaces it on reconnect/disconnect) instead of `$global:deviceManager`, and every other public/private cmdlet falls back to it when `-WebSession` is omitted. See `ANALYSIS.md` finding S6 for the narrowed security posture.
- [x] ~~Expand `ShouldProcess` on state-changing actions.~~ Done in v0.9.4: all 74 mutating public commands (`New-DM*`, `Set-DM*`, `Remove-DM*`, `Rename-DM*`, `Add-DM*`, etc.) declare `SupportsShouldProcess = $true` and call `$PSCmdlet.ShouldProcess()` before their destructive/mutation REST call, giving native `-WhatIf`/`-Confirm` support. See `RELEASE_NOTES.md` v0.9.4.
- [x] ~~Modernize Pester configuration.~~ Already on Pester 5 idioms throughout: `Tests/Invoke-UnitTests.ps1` uses `New-PesterConfiguration`/`Invoke-Pester -Configuration`; all 48 test files use `Should -Invoke` (zero `Assert-MockCalled`/`Assert-VerifiableMock` legacy calls) and explicit `Describe`/`It` blocks, with 32 of 48 using `BeforeDiscovery` for discovery/run-phase separation.
- [x] ~~Pin an upper Pester version bound.~~ `Tests/Invoke-UnitTests.ps1` now imports Pester with `-MinimumVersion 5.0.0 -MaximumVersion 5.99.99`, so a future Pester 6 major release can't be picked up silently and break CI on breaking-change assumptions; the ceiling must be bumped deliberately after validating against it. The GitHub Actions workflow (`.github/workflows/powershell.yml`) already installs an exact pinned version (`5.7.1`), so it's unaffected.
- [x] ~~Automate PSScriptAnalyzer integration.~~ `Tests/Invoke-UnitTests.ps1` now runs `Invoke-ScriptAnalyzer` before the Pester pass (non-blocking by default — prints a per-severity summary; `-FailOnAnalyzerIssue` makes it throw, `-SkipAnalyzer` skips it; gracefully warns and continues if PSScriptAnalyzer isn't installed locally). All 115 previously-open Warning/Information findings were resolved: 48 `PSUseOutputTypeCorrectly` fixed by adding `[OutputType(...)]` matching each command's actual inferred return type; 14 `PSAvoidTrailingWhitespace` stripped; 53 `PSUseBOMForUnicodeEncodedFile` fixed by writing a UTF-8 BOM (deliberate choice, not just rule-compliance: this codebase's comment-based help contains non-ASCII characters like em-dashes, and Windows PowerShell 5.1 — still common in enterprise storage-admin environments — reads non-BOM UTF-8 files using the system codepage, which can mis-render or mis-parse them). `Invoke-ScriptAnalyzer -Path ./POSH-Oceanstor -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse` now reports zero issues.
- [x] ~~Establish GitHub Actions CI Workflow.~~ `.github/workflows/powershell.yml` (name differs from the originally proposed `ci.yml`, functionally identical) already runs a `PSScriptAnalyzer` job (full ruleset minus the settings-file exclusions, uploads SARIF) and a `Pester Unit Tests` job (`Tests/Invoke-UnitTests.ps1` with coverage) across a `windows-latest`/`ubuntu-latest`/`macos-latest` matrix, triggered on every push to `master`, every PR into `master`, and a weekly schedule.
- [x] ~~Standardize REST error mapping.~~ The try/catch wrapping was already done (`Private/Invoke-DeviceManager.ps1` is the single chokepoint every command funnels through). The real gap — mutation commands (`New-DM*`/`Set-DM*`/`Remove-DM*`/`Add-DM*`/`Enable-DM*`/`Restore-DM*`/`Restart-DM*`/`Resize-DM*`, 68 files) silently `return`ing the raw API error object instead of throwing, unlike `Get-DM*` commands which already threw via `Select-DMResponseData` — is fixed by a new shared helper `Private/Assert-DMApiSuccess.ps1` that every mutation command now pipes its `Invoke-DeviceManager` response through. It throws a structured `ErrorRecord` (`ErrorCategory.InvalidOperation`, `ErrorId 'OceanStorApiError'`) using the same message format `Select-DMResponseData` already uses, on a non-zero `error.Code`; passes the response through unchanged on success, so nothing about what a successful mutation command returns changed. `Select-DMResponseData`/`Invoke-DeviceManager` themselves were left untouched (both already correct; routing through them would have multiplied the test-mock blast radius for no behavioral gain).
- [x] ~~Improve the session-expired error message.~~ New shared formatter `Private/Get-DMApiErrorMessage.ps1` appends an actionable hint ("call Connect-deviceManager again") when the response's error code matches a small, deliberately narrow known-codes table (currently just `1077939726`, the "session expired" code already used as a test fixture in this codebase). Wired into all four places that independently built this message: `Select-DMResponseData.ps1`, `Assert-DMApiSuccess.ps1`, `Invoke-DMPagedRequest.ps1`, and a bespoke inline check in `Get-DMhost.ps1` that predated `Select-DMResponseData` and had never been migrated (found by grepping for any remaining `.error.Code -ne 0` check not already routed through one of the shared helpers). `Invoke-DMPagedRequest`/`Get-DMhost`'s existing "for resource 'X'" context is preserved via an optional `-ResourceContext` parameter.

---

## Rejected

- [x] ~~Build Dynamic Parameter-to-Payload Transformer.~~ **Rejected** — audited the actual `$body` construction across `New-DM*`/`Set-DM*` commands (e.g. `New-DMLun.ps1`, `New-DMFileSystem.ps1`, `New-DMHost.ps1`) and found the parameter-to-payload mapping is not mechanical: key renames don't follow PascalCase→UPPERCASE (`-LunName` → `NAME`, `-StoragePoolID` → `PARENTID`, `-EnableCache` → `ENABLE_CACHE`), most fields need value transforms (capacity→blocks, friendly enum strings → Huawei numeric codes, bool→int casts) or are hardcoded constants unrelated to any parameter (`TYPE = 21`), and `Set-*` commands rely on `$PSBoundParameters.ContainsKey(...)` gating per field for PATCH semantics. A generic reflection-driven transformer would only cover the small mechanical slice and still need per-field override logic for everything else — net more indirection, not less. Established REST-wrapping PowerShell modules (Az, PowerCLI, NetApp/Pure SDKs) don't hand-roll this either; they use SDK-generated clients or hand-write the body per command, which is what this module already does.
- [x] ~~Build Active Token Lifecycle Validation.~~ **Rejected** — re-authentication using "securely cached session parameters" directly conflicts with a design decision this module already made: `Private/class-OceanstorSession.ps1` has a commented-out `$Credentials` field with the author's own reasoning attached ("dont want to have the credentials in memory for long time"), matching `ANALYSIS.md` finding S2 (plaintext password wiped immediately after login). Silent re-auth needs a reusable secret retained for the session's lifetime — reopening the exact exposure that decision closed — and Huawei's login flow (Basic-Auth-once-for-an-opaque-token) has no refresh-token primitive to build on the way OAuth2-based CLIs (Azure/AWS/GCP) do. The `Test-DMSession` expiry-check half is also weak on its own: the module never captures a token TTL from the login response (none is returned), so "close to expiry" means either hardcoding an undocumented, unverifiable assumed timeout or proactively pinging before every real call — an inherently racy check (TOCTOU) that duplicates what "attempt the call, handle the failure" already does. See the narrower message-quality fix implemented instead, in Completed below.
