# Network TODO

## Current Focus

- Both supervised network-stack workflows in the integrity harness
  (`-RunSupervisedTests` + `Network.Enabled` + `Network.Supervised.Enabled` + a
  per-stack gate) are now **live-validated**. Codified in
  `Tests/Integration/Private/Workflows/SupervisedNetwork.ps1`:
  - `AllowNetworkStackLifecycle` — bond + 4 VLANs + 4 role-LIFs (live-validated
    2026-07-09; mirrors `prompt-network-stack-supervised-test.md`).
  - `AllowFailoverGroupStackLifecycle` — failover group + 2 VLAN members +
    service LIF. **Live-validated 2026-07-20 (operator-supervised, lab array
    10.10.10.24, ports `CTE0.A.IOM0.P2` + `CTE0.B.IOM0.P2`).** Full pass: two
    VLANs (same tag, one per port) → customized NAS failover group → both added
    as members (getter reported **2**) → group description modify + read-back →
    service LIF (`Role=Service`, `10.130.10.1/24`, home `CTE0.A.IOM0.P2.130`)
    with its failover binding **surfacing on read-back** (`Failover Group Id=1`,
    `Can Failover=True`) → discrete member remove (getter reported **1**) →
    LIFO teardown by captured ID, **zero leftovers**, both ports back to
    `link down`/unbonded. Nothing pre-existing was touched. Two firmware/
    environment findings recorded below.

### Findings from the 2026-07-20 FG live run

- **FG member VLANs must share one tag id.** The array rejects members with
  different VLAN tags: `1073815814` ("VLAN ports with different IDs cannot be
  added to one failover group"). A failover group spans **the same tag across
  different ports** (as the production NAS pair does: `CTE0.A/B.IOM0.P0.50`).
  The harness `Invoke-SupervisedFailoverGroupStack` and the
  `prompt-network-failovergroup-supervised-test.md` reference script used two
  distinct tags (130 & 131) and were **fixed to a single shared tag** (first
  `VlanTags` entry, 130) on both ports. (The bond network-stack workflow, by
  contrast, correctly uses four distinct tags for four VLANs on one bond.)
- **LIF↔failover-group binding reads back cleanly.** The earlier
  `NeedsInvestigation` caveat (that `OceanStorLIF` might not surface
  `Failover Group Id` / `Can Failover`) is **resolved**: both fields returned
  correctly on read-back for a service LIF created with `-FailoverGroupId`
  `-CanFailover`. No field-mapping gap on this path.
- **Blocker cleared: orphaned `BondTest` stack removed.** `CTE0.A.IOM0.P2` was
  trapped in a leftover test bond `BondTest` → VLAN `BondTest.123` → LIF
  `testelif2` (`10.123.10.1`), debris from an earlier session. The invariant
  precheck missed it (`Port Bond Id` reads blank), but the status helper
  `Get-DMVlanParentPortStatus` reported it (`Reasons=[Port is a member of
  bond(s): BondTest.]`). With operator authorization it was removed by captured
  ID (LIFO: LIF → VLAN → bond), freeing the port; the guard then reported only
  the expected `System-defined` membership.

## Medium Priority

- Live member add/remove step — **done (2026-07-20).** The supervised
  failover-group stack creates two test-owned VLANs (REST `ASSOCIATEOBJTYPE`
  280) on the operator-designated ports and adds/removes them as members. The
  old blocker (harness owned no eligible member object) is resolved. Exercised
  live: both members added (getter → 2), then one removed discretely (getter →
  1), verified by read-back rather than the non-terminating call's silent
  return. The LIF↔failover-group binding read-back is confirmed (see
  Current Focus findings above). The idle-port guard
  (`Get-DMVlanParentPortStatus`) ran as a recorded dry-run, not a gate.

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
    the tag, e.g. `<port>.123`). **Static analysis 2026-07-17: the class
    mapping is correct against the 6.1.6 reference.** All three VLAN GET
    interfaces — batch `GET vlan` (§4.6.9.4.9), single `GET vlan/{id}`
    (§4.6.9.4.36) and `GET vlan/associate` (§4.6.12.1.1) — document `TAG`
    (string(uint32), example `"TAG": "123"`), and `OceanStorvLan` reads
    `$vlanReceived.TAG` into `Vlan Tag Id`. A repro constructing the class from
    the reference's own example JSON yields `Vlan Tag Id = 123` correctly, so
    this is **not** a field-name mismatch (unlike the syslog case). The empty
    live value is therefore a firmware/response discrepancy — the lab array's
    `GET vlan` element apparently omitted or emptied `TAG` for those VLANs.
    Not statically fixable and not safe to guess an alternate field name for.
    **Next step (Phase 2 VLAN live session):** capture the raw `GET vlan` JSON
    on the lab array and diff it against the documented schema; only then decide
    whether a tolerant fallback field name is warranted.
  Details in [safety-and-live-validation.md](safety-and-live-validation.md).
- `Set-DMvLan` (`PUT vlan/{id}`, MTU change) rejected raw-PUT update experiments
  with OceanStor API error `50331651` whether `NAME` was omitted or set —
  **root-caused + fixed 2026-07-17.** The earlier `NAME` experiments were a red
  herring: the modify interface (§4.6.9.3.8) documents no `NAME` field at all and
  marks **both `ID` and `MTU` Mandatory** in the body. `Set-DMvLan` was sending
  only `MTU` (ID in the URL path alone), which the array rejects — the same
  omission pattern as the SNMP-trap `50331651` fix. `Set-DMvLan` now echoes
  `ID` in the body alongside `MTU`; unit test added
  (`Tests/Unit/Public/Set-DMvLan.Tests.ps1`) asserting the corrected body.
  **Awaiting live re-confirm in the Phase 2 VLAN session.**
- `Set-DMFailoverGroup` (`PUT failovergroup/{id}`, NAME/DESCRIPTION change) omitted the
  Mandatory `ID` body field — **root-caused + fixed 2026-07-17 (static analysis).** The
  modify interface (§4.6.9.3.7) marks **`ID` Mandatory** in the body; NAME/DESCRIPTION/
  MSGRETURNTYPE are Optional. The doc's terse example body is ID-less, but the Parameters
  table is the contract — the same `50331651` omission pattern as the SNMP-trap and
  `Set-DMvLan` fixes. `Set-DMFailoverGroup` now echoes `ID` in the body (added to its
  `ConvertTo-DMRequestBody` map; `Id` is a Mandatory parameter, so it is always present)
  alongside the URL path; unit assertion added to
  `Tests/Unit/Public/Network-Actions.Tests.ps1`. **Live-confirmed 2026-07-17 against a
  V600R005C27 lab array (10.10.10.24): a throwaway customized failover group was created,
  its description modified via `Set-DMFailoverGroup` (accepted — no `50331651`), read back,
  and removed by captured ID; array state restored, no leftovers.**

## Low Priority / Polish

- Friendly-name aliases (`-BondPortType HostService`,
  `-AssociateObjectType EthernetPort`) and richer `OceanStorvLan` /
  `OceanStorPortBond` display-field decoding — **code enhancements** tracked in
  the code backlog, not docs-only items.

## Testing and Validation

- Read-only network getters are covered by live read validation; keep new
  getters registered there as they are added
  (`Get-DMFailoverGroupMember` registered 2026-07-07).
- Network mutators must stay out of default live runs; any future live
  workflow must be config-gated and strictly test-owned (see
  [safety-and-live-validation.md](safety-and-live-validation.md)). The
  failover-group workflow follows this pattern and stays off by default;
  `-RunMutatingTests` alone never runs it.
- The supervised network-stack category (bond/VLAN/LIF create-remove and the
  failover-group NAS stack) is a stricter tier: it requires the dedicated
  `-RunSupervisedTests` switch **and** `Network.Supervised.Enabled` **and** a
  per-stack `Allow*` gate, operates only on operator-designated link-down ports
  re-verified read-only, and tears down every object by captured ID in reverse
  order. `-RunMutatingTests` never triggers it. Classification is unit-covered
  in `Tests/Unit/Private/ValidationReporting.Tests.ps1`.
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
