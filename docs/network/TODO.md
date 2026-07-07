# Network TODO

## Current Focus

- First human-supervised, config-gated live run of the failover-group
  workflow (`Network.Enabled` + `Network.AllowFailoverGroupLifecycle`).

## Recently Completed

- Phase 06 (2026-07-07) network hardening:
  - `-WhatIf` regression tests for all 15 network mutators
    (no-API-call assertion driven by the shared
    `Tests/Unit/Support/Assert-DMWhatIfSafe.ps1` helper, reusable by the
    Phase 07 DR `-WhatIf` suite), plus `ConfirmImpact = 'High'` checks for
    in-place modify/delete mutators. `Set-DMLLDPWorkingMode` now declares
    `ConfirmImpact = 'High'`.
  - Failover-group member getter `Get-DMFailoverGroupMember` (typed
    `OceanStorFailoverGroupMember` output, registered in read validation and
    `ModuleCoverage.psd1`). Note: `failovergroup/associate` has **no
    documented GET** in the Dorado 6.1.6 REST reference; the getter uses the
    documented per-type queries (`eth_port/associate`, `bond_port/associate`,
    `vlan/associate` with `ASSOCIATEOBJTYPE=289`) instead.
  - Server-side narrowing for `Get-DMLif`/`Get-DMvLan`: documented
    `filter=NAME` (exact `::`, fuzzy `:`, client-side `-Like` re-check) and
    documented `lif/{id}` / `vlan/{id}` single-object queries for `-Id`.
  - `Set-DMLif` addresses a LIF by `-Id` alone (resolves the documented
    mandatory `NAME` body field via `lif/{id}` first); `-Name`-only behavior
    unchanged.
  - Pipeline property-binding tests: `Get-DMPortBond | Remove-DMPortBond`,
    `Get-DMFailoverGroup | Set-DMFailoverGroup`, `Set-DMLif` by piped
    `Id`/`LIF Name`.
  - Config-gated, test-owned failover-group workflow
    (`Tests/Integration/Private/Workflows/FailoverGroup.ps1`), disabled by
    default behind `Network.Enabled` + `Network.AllowFailoverGroupLifecycle`;
    cleanup by captured ID only; member add/remove skipped until a
    test-owned member type exists.
  - VLAN idle-port guard design documented in
    [safety-and-live-validation.md](safety-and-live-validation.md).
- Bond port lifecycle: `New/Set/Remove-DMPortBond`.
- VLAN port lifecycle: `New/Set/Remove-DMvLan`.
- Logical port (LIF) lifecycle: `New/Set/Remove-DMLif`.
- Failover group lifecycle: `Get/New/Set/Remove-DMFailoverGroup`,
  `Add/Remove-DMFailoverGroupMember`, typed `OceanStorFailoverGroup` output.
- LLDP working mode: `Get/Set-DMLLDPWorkingMode`.
- Shared `ConvertTo-DMRequestBody` helper for parameter→REST body mapping.
- Paged-request hardening: per-page `-TimeoutSec` and identical-page loop
  detection in `Invoke-DMPagedRequest`.
- Unit tests for all new getters and mutators
  (`Network-Actions.Tests.ps1`, `Get-Network.Tests.ps1`, LLDP cases in the
  system-configuration test files).
- `Get-DMFailoverGroup` and `Get-DMLLDPWorkingMode` registered in live
  read validation; `New-DMRequestBody.ps1` added to the harness dot-source
  whitelist.

## High Priority

- Human-supervised, gated live run of the failover-group workflow, then
  record the run outcome here.

## Medium Priority

- Expose the remaining documented filter fields as parameters:
  `Get-DMLif` (`IPV4ADDR`, `IPV6ADDR`, `HOMEPORTID`) and `Get-DMvLan`
  (`TAG`, `fatherDrvType`).
- Live member add/remove step in the failover-group workflow — **blocked**:
  members are Ethernet ports / bond ports / VLANs (REST `ASSOCIATEOBJTYPE`
  213/235/280, not LIFs), and the harness owns no such object. Requires the
  test-owned VLAN workflow with the idle-port guard first.

## Deferred (with reason)

- Bond member add/remove after creation — **no documented REST endpoint**:
  `PUT bond_port/{id}` documents only `NAME`, `MTU`, IP address fields,
  `MSGRETURNTYPE` and `USEDTYPE`; no `PORTIDLIST`/member operation exists in
  the Dorado 6.1.6 reference (verified 2026-07-07). Do not send speculative
  bodies; revisit when Huawei documents one.
- `Get-DMFailoverGroupMember` via a single `failovergroup/associate` GET —
  **no documented REST endpoint** (only POST/DELETE are documented); the
  implemented per-type association queries are the documented alternative.
- VLAN live workflow — **requires idle-port guard** (design in
  [safety-and-live-validation.md](safety-and-live-validation.md)); the guard
  itself needs tests and a reviewed lab dry run before any
  `Network.AllowVlanLifecycle` gate may exist.

## Low Priority / Polish

- Friendly-name parameters instead of raw enums (`-BondPortType HostService`,
  `-AssociateObjectType EthernetPort`) with back-compat for numeric values.
- Decode more display fields on `OceanStorvLan` / `OceanStorPortBond`
  (running status, MTU) the way `OceanStorFailoverGroup` does.

## Testing and Validation

- Read-only network getters are covered by live read validation; keep new
  getters registered there as they are added
  (`Get-DMFailoverGroupMember` registered 2026-07-07).
- Network mutators must stay out of default live runs; any future live
  workflow must be config-gated and strictly test-owned (see
  [safety-and-live-validation.md](safety-and-live-validation.md)). The
  failover-group workflow follows this pattern and stays off by default;
  `-RunMutatingTests` alone never runs it.
- VLAN live workflow (create/delete a tagged child on a verified-idle port)
  is possible in a dedicated lab but needs the documented idle-port detection
  guard implemented and tested first.

## Documentation

- Keep the per-domain pages in this folder in sync when parameters change.
- NAS-provisioning walkthrough (failover group → LIF → share) added to
  [failover-groups.md](failover-groups.md) (2026-07-07).

## Future Feature Branches

> Status: `open`, explicitly out of scope for
> `todo/alpha-v1.0.0-post-merge-phase-06-network-hardening-and-workflows.md`
> (no active phase targets these yet).

- Routes and gateways (query/create/delete static routes) — not implemented.
- iSCSI portal / CHAP configuration cmdlets.
- NVMe-oF interface configuration cmdlets.
- Per-port network performance/statistics getters.
- LLDP neighbor information getter.

## Not Planned / Unsafe by Default

- Physical port mutation (enable/disable, MTU, speed, IP on `eth_port` /
  `fc_port`) — high risk of severing management or data access.
- Management IP / management route changes.
- Live execution of `Set-DMLLDPWorkingMode` — global setting with no
  test-owned variant.
- Broad or name-pattern cleanup of network objects in any test.

## Notes for Contributors

- Every mutating network cmdlet must declare `SupportsShouldProcess`;
  in-place modifications and deletions should use `ConfirmImpact = 'High'`.
- Build request bodies with `ConvertTo-DMRequestBody` so unset parameters are
  never transmitted.
- New private helper files must be added to the dot-source whitelist in
  `Tests/Integration/Invoke-GetterIntegrityValidation.ps1`, or cmdlets will
  fail only during live validation.
- New getters: register them in
  `Tests/Integration/Private/ReadValidation.ps1` with their expected output
  type, and add the output class to `Tests/ModuleCoverage.psd1`.
