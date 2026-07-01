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

### Code Quality & Linting Compliance

- [ ] **Enforce Strict PascalCase/lowercase Standards**
  - [x] Standardize keywords (`if`, `else`, `foreach`, `try`, `catch`) to lowercase.
  - [x] Standardize logical constants (`$true`, `$false`) to lowercase across all `.psm1` and helper script files.
- [ ] **Automate PSScriptAnalyzer Integration**
  - Embed `Invoke-ScriptAnalyzer` checks into the local testing loop.
  - Resolve all remaining Severity: Warning / Information items.

### Module Integrity & UX Optimization

- [ ] **Enforce Explicit Export Controls**
  - Update `POSH-Oceanstor.psd1` to explicitly populate `FunctionsToExport`.
  - Shift from wildcard exports (`*`) to explicit names to improve module load time and baseline command discovery.
- [ ] **Standardize Noun Cardinality**
  - Refactor public endpoint nouns from plural to singular where needed, for example `Get-DMLuns` to `Get-DMLun`.
  - Rely on pipeline processing or array-bound parameters to handle multi-object output naturally.

### Native Pipeline & Context Architecture

- [ ] **Implement Complete Pipeline Support**
  - Add `ValueFromPipeline` and `ValueFromPipelineByPropertyName` attributes to core parameters inside targeting commands.
  - Structure cmdlets with proper `begin {}`, `process {}`, and `end {}` blocks to prevent multi-object arrays from flattening or dropping records.
- [ ] **Implement Module/Script-Scoped Session Fallback**
  - Initialize an internal module variable: `$script:CurrentOceanstorSession`.
  - Update `Connect-DeviceManager` to cache successful web sessions into this variable.
  - Update all `Get-` and configuration cmdlets to fall back to `$script:CurrentOceanstorSession` when `-WebSession` is omitted.

### Resilient REST API Integration

- [ ] **Build Active Token Lifecycle Validation**
  - Develop a private helper function `Test-DMSession` to check whether the active Huawei DeviceManager token is close to expiry or invalid.
  - Implement a re-authentication routine using securely cached session parameters if a token times out during an active session block.
- [ ] **Standardize REST Error Mapping**
  - Wrap `Invoke-RestMethod` logic in unified `try`/`catch` handling.
  - Parse Huawei OceanStor-specific JSON error payloads and transform them into native PowerShell `ErrorRecord` objects with `Write-Error`.

### Data Guardrails & Safety

- [ ] **Expand `ShouldProcess` on State-Changing Actions**
  - Confirm all destructive/mutation endpoints use `SupportsShouldProcess = $true`.
  - Enforce native support for `-WhatIf` and `-Confirm` parameters across mutating API interactions.
- [ ] **Build Dynamic Parameter-to-Payload Transformer**
  - Create an internal private helper `ConvertFrom-DMParameterToPayload`.
  - Map PascalCase PowerShell parameters such as `-LunId` into the native REST payload keys required by DeviceManager via `$PSBoundParameters`.

### Testing, CI/CD, & Supply Chain Security

- [ ] **Modernize Pester Configuration**
  - Audit and transition the `Tests/` directory structure to modern Pester 5+ syntax standards.
  - Prefer explicit `BeforeAll`, `Describe`, `Context`, and `It` block segmentation where it improves readability.
- [ ] **Develop Robust API Mocking**
  - Build comprehensive `Mock Invoke-RestMethod` templates that mimic real Huawei OceanStor v6 responses.
  - Keep code-path validation isolated and safe without requiring a physical SAN connection.
- [ ] **Establish GitHub Actions CI Workflow**
  - Create `.github/workflows/ci.yml` to execute PSScriptAnalyzer and the Pester test suite on every pull request or main branch push.
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

- [x] ~~Expand unit coverage for public commands that had no direct tests.~~ `Disconnect-deviceManager`, `New-DMnfsShare`, `New-DMnfsClient`, and `Set-DMdnsServer` have dedicated tests. All 127 public commands are referenced in at least one unit test file.
- [x] ~~Define a consistent minimum object-method surface, such as `Rename()`, `Delete()`, and relationship helpers, for mutable returned objects.~~ `Delete()` was added to all mutable classes that lacked it, including LUN, file system, host, group, mapping view, NAS share, and dTree classes. Each method is covered by the corresponding class tests.
- [x] ~~Generate command/object inventory during CI and fail when a new public command or class is absent from maintained coverage metadata.~~ `Tests/ModuleCoverage.psd1` records all class names. `Tests/Unit/Private/ModuleInventory.Tests.ps1` cross-checks every `Public/*.ps1` file against `FunctionsToExport` and every `Private/class-*.ps1` file against `ModuleCoverage.psd1`.
