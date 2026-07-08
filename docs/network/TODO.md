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
- Phase 05 (2026-07-08) network carry-over:
  - `Get-DMLif` filter parameters `-Ipv4Addr` / `-Ipv6Addr` / `-HomePortId`
    (documented `IPV4ADDR` / `IPV6ADDR` / `HOMEPORTID` fields) and `Get-DMvLan`
    filter parameters `-Tag` / `-FatherDrvType` (documented `TAG` /
    `fatherDrvType` fields). All sent server-side, AND-composed with `-Name`,
    unit-tested in `Get-Network.Tests.ps1`.
  - VLAN idle-port guard **implemented and unit-tested** as private helper
    `Get-DMVlanParentPortStatus` (read-only; returns Idle/InUse/Unknown, treats
    unknown as unsafe; tests in
    `Tests/Unit/Private/Get-DMVlanParentPortStatus.Tests.ps1`). Gate
    `Network.AllowVlanLifecycle` defined in `IntegrityValidationConfig.psd1`,
    **default off**. No live VLAN validation run.
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
  - **Status (Phase 03, 2026-07-07): Deferred — not run this session.** The
    2026-07-07 supervised session used its single mutation gate for the
    SystemManagement SNMP-trap surface (one-gate-per-session discipline), so
    `Network.Enabled` + `AllowFailoverGroupLifecycle` stayed **off**. Workflow,
    gate, and captured-ID cleanup are verified in place
    (`Tests/Integration/Private/Workflows/FailoverGroup.ps1`); this needs its own
    dedicated supervised session. Blocker: operator scheduling of a separate
    single-gate run against a non-production lab.

## Medium Priority

- Live member add/remove step in the failover-group workflow — **blocked**:
  members are Ethernet ports / bond ports / VLANs (REST `ASSOCIATEOBJTYPE`
  213/235/280, not LIFs), and the harness owns no such object. The idle-port
  guard now exists (`Get-DMVlanParentPortStatus`), but a live test-owned VLAN
  workflow that produces such a member must run first — still deferred.

## Deferred (with reason)

- Bond member add/remove after creation — **no documented REST endpoint**:
  `PUT bond_port/{id}` documents only `NAME`, `MTU`, IP address fields,
  `MSGRETURNTYPE` and `USEDTYPE`; no `PORTIDLIST`/member operation exists in
  the Dorado 6.1.6 reference (verified 2026-07-07). Do not send speculative
  bodies; revisit when Huawei documents one.
- `Get-DMFailoverGroupMember` via a single `failovergroup/associate` GET —
  **no documented REST endpoint** (only POST/DELETE are documented); the
  implemented per-type association queries are the documented alternative.
- VLAN live workflow — idle-port guard `Get-DMVlanParentPortStatus` is now
  implemented and unit-tested, and the `Network.AllowVlanLifecycle` gate is
  defined (**default off**). Still deferred: the live create/delete run needs a
  reviewed lab dry run of the guard against real hardware and a verified-idle
  parent port the harness owns. No live VLAN run was performed. Details in
  [safety-and-live-validation.md](safety-and-live-validation.md).

## Low Priority / Polish

- Friendly-name parameters instead of raw enums (`-BondPortType HostService`,
  `-AssociateObjectType EthernetPort`) with back-compat for numeric values.
  **(Code enhancement — not implemented.)** Phase 08 documented the current
  raw-value behavior as deferred in [bond-ports.md](bond-ports.md) and
  [vlans.md](vlans.md) so operators do not assume the aliases exist.
- Decode more display fields on `OceanStorvLan` / `OceanStorPortBond`
  (running status, MTU) the way `OceanStorFailoverGroup` does.
  **(Code enhancement — not implemented.)** Phase 08 added display-field /
  prefer-IDs notes to [bond-ports.md](bond-ports.md), [vlans.md](vlans.md), and
  [logical-ports.md](logical-ports.md).

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
  is possible in a dedicated lab. The idle-port detection guard is now
  implemented and unit-tested (`Get-DMVlanParentPortStatus`); the remaining
  prerequisite is a human-reviewed lab dry run of the guard before any gated
  live create/delete.

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
