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
  - **Status (2026-07-09): Passed — live run completed.** With
    `Network.Enabled` + `AllowFailoverGroupLifecycle` on, the lab run
    (run ID 20260709033729) exercised the full lifecycle on a test-owned
    group: `New-DMFailoverGroup`, read-back, `Set-DMFailoverGroup`,
    read-back, `Get-DMFailoverGroupMember` (zero members), and
    `Remove-DMFailoverGroup` by captured ID — all `Passed`, no leftovers.
    Member add/remove stayed `SkippedUnsafe` by design (see Medium
    Priority). The first attempt exposed a `Get-DMFailoverGroup -Name`
    bug (a `$null` REST response materialized one phantom object, so the
    pre-create ownership guard misfired); fixed with the standard
    null-guard in the response loop and covered by existing unit tests.

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
  - Bond **create/remove** (members fixed at creation) is validated live as of
    2026-07-09: in an operator-supervised session on two designated free
    front-end ports (link down, `host port/service port`, no LIF/VLAN/bond
    association), `New-DMPortBond -PortIdList` created a run-owned bond
    (read back `link down`/`normal`), `New-DMvLan -PortType 7` created VLAN
    123 on that bond, and teardown ran in inverse order — VLAN removed by
    captured ID, then the bond — leaving zero test objects and both member
    ports unchanged. Follow-up finding: the `Get-DMPortBond` read-back shows
    an empty `Port List` property (same class field-mapping gap as the empty
    `Get-DMvLan` `Tag`; NeedsInvestigation).
  - **Full network stack validated live 2026-07-09 (operator-supervised):**
    bond on the two designated link-down front-end ports → VLANs
    123/124/125/126 on the bond (`New-DMvLan -PortType 7`) → four LIFs
    (`New-DMLif -HomePortType 8`, one per VLAN) with roles management (1),
    service (2), replication (4), and management+service (3), each with a
    run-unique `10.12x.10.1/24` address. All read-backs correct (role, IP,
    mask, home VLAN), then everything deleted in exact reverse creation
    order (LIFs → VLANs 126..123 → bond) by captured ID; post-run checks
    showed zero test objects and unchanged ports/pre-existing VLANs.
    Dependency ordering was also negatively confirmed: the array refuses
    `Remove-DMvLan` while a LIF exists on the VLAN (`1073813505`) and
    `Remove-DMPortBond` while VLANs exist on the bond (`1073801985`).
    New class field-mapping findings (NeedsInvestigation, same family as
    the `Tag`/`Port List` gaps): `OceanStorLIF` exposes the name only as
    `LIF Name` (no `Name` property, unlike sibling classes), and the LIF
    `Role` decode table renders replication (code 4) as an empty string.
  - **Repeat run 2026-07-09, operator-supervised, with two in-place
    `Set-DMLif` modifications requested before teardown:** same bond +
    VLAN(123-126) + LIF(mgmt/service/replication/mgmt+service) stack
    recreated and validated identically to the baseline run above (same
    replication role-decode gap observed again). The operator then
    requested two live modifications on already-validated LIFs, still
    before teardown: add `IPv4Gateway 10.124.10.254` to the LIF at
    `10.124.10.1`, and change the `IPv4Address` of the LIF at
    `10.123.10.1` to `10.123.10.100`. **Both `Set-DMLif` calls failed
    silently**: the array returned OceanStor error `1077948993` ("The
    object name already exists") for each, but `Set-DMLif` treats API
    failures as non-terminating (`catch { $PSCmdlet.WriteError($_) }`), so
    neither call threw and a naive caller would see apparent success. A
    post-modify read-back (added specifically to guard this step) caught
    the discrepancy — gateway still empty, IP unchanged — and the script
    aborted before teardown; teardown itself ran unconditionally from a
    `finally` block and completed normally (LIFs 126→125→124→123, VLANs
    126→125→124→123, then the bond, all by captured ID), leaving zero test
    objects and both ports back to `link down`/unbonded. No pre-existing
    object was touched at any point, and neither requested modification
    ever actually took effect on the array.
    - **Root cause confirmed by live re-test 2026-07-09 (operator-supervised,
      lab array 10.10.10.24) — the path-scoped-PUT hypothesis above was
      investigated and disproven.** There is no `PUT lif/{id}` endpoint in
      the Dorado 6.1.6 REST reference (unlike `bond_port`/`failovergroup`);
      `NAME` is a documented mandatory field for every `PUT lif` call. Five
      raw-body variants were tested against a test-owned VLAN+LIF pair (via
      `Invoke-DeviceManager` called directly at module scope, bypassing
      `Set-DMLif`'s non-terminating error handling so every outcome
      surfaced), with full LIFO teardown and zero leftovers confirmed after
      each run:

      | Variant | Body sent | Result |
      |---|---|---|
      | A — `Set-DMLif -Id` (current behavior) | `ID`, `NAME`(current, auto-resolved), `IPV4GATEWAY` | `THROW` 1077948993 "The object name already exists" |
      | B — raw PUT, NAME omitted | `ID`, `IPV4GATEWAY` | `THROW` 50331651 "The entered parameter is incorrect" |
      | C — raw PUT, NAME resent unchanged | `ID`, `NAME`(current), `IPV4GATEWAY` | `THROW` 1077948993 "The object name already exists" |
      | E — raw PUT, NAME set to a new distinct value | `ID`, `NAME`(new), `IPV4GATEWAY` | `THROW` 50331651 "The entered parameter is incorrect" |
      | F — raw PUT, pure rename, no other field | `ID`, `NAME`(new) | **SUCCESS**, errorCode=0, read-back confirms new name |

      Conclusion: on this firmware, `PUT lif` accepts a bare rename (`NAME`
      changed, nothing else) but rejects combining `NAME` with any other
      simultaneously-changing property, regardless of whether `NAME` is
      omitted, unchanged, or newly different. This is an **array-firmware
      self-collision/validation bug**, not a `Set-DMLif` implementation
      defect — the current implementation already matches the documented
      REST contract, and raw calls with an identical body shape reproduce
      the same failure outside the module entirely. **No client-side PUT
      body variant works around it**; there is no code fix to apply.
      Remediation applied: `Get-DMApiErrorMessage.ps1` now attaches an
      actionable hint to error 1077948993 pointing back to this finding, so
      operators see an explanation instead of a raw Huawei code.
      `Set-DMLif` itself is unchanged — its non-terminating error handling
      is correct/by-design; callers must still read back after every call
      (as the diagnostic runs above already do) since a caught API error
      never implies partial application here.
- `Get-DMFailoverGroupMember` via a single `failovergroup/associate` GET —
  **no documented REST endpoint** (only POST/DELETE are documented); the
  implemented per-type association queries are the documented alternative.
- VLAN live workflow — **validated 2026-07-09 in an operator-supervised
  session.** With the operator explicitly designating two lab parent ports and
  tag 123, `New-DMvLan` (PortType 1) created a run-owned VLAN on each
  designated port (both read back `link up`), and `Remove-DMvLan` deleted both
  strictly by captured ID; post-run checks confirmed zero tag-123 objects
  remain and the ports' pre-existing VLAN objects were untouched. Two findings
  for follow-up:
  - Guard calibration: `Get-DMVlanParentPortStatus` reported `InUse` for
    every ethernet port on the lab array because the built-in
    `System-defined` failover group contains all ports, and the lab ports
    already parent a production-style VLAN. As designed the guard can
    therefore never green-light a port on such an array — the unattended
    harness workflow stays `SkippedUnsafe`, and live VLAN runs remain
    operator-designated-port sessions like this one (or the guard learns to
    ignore the `System-defined` group and accept operator-supplied ports via
    config).
  - `Get-DMvLan` returns an empty `Tag` property for live VLANs (names embed
    the tag, e.g. `<port>.123`); the class field mapping needs a look
    (NeedsInvestigation).
  Details in [safety-and-live-validation.md](safety-and-live-validation.md).

## Low Priority / Polish

- _Docs polish done (Phase 08)._ Raw-enum-vs-friendly-name behavior and the
  display-field / prefer-IDs guidance are documented in
  [bond-ports.md](bond-ports.md), [vlans.md](vlans.md), and
  [logical-ports.md](logical-ports.md). The remaining friendly-name aliases
  (`-BondPortType HostService`, `-AssociateObjectType EthernetPort`) and richer
  `OceanStorvLan` / `OceanStorPortBond` display-field decoding are **code
  enhancements** tracked in the code backlog, not docs-only items.

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

> Status: `open`, not yet scheduled against any active phase. Tracked in the
> current open-issues / remaining-open-todos planning set.

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
