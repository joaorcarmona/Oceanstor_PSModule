# alpha-v1.0.0 Open Issues Phase 05 — Network / Block / NAS Carry-Over Gaps

**Type:** Code + Tests (+ Live-validation planning for the VLAN idle-port guard). **Live validation:**
none executed here (the VLAN live workflow is *planned* only — it is blocked on the guard).
**Release-blocking:** NO.

## Purpose

Close the non-safety-critical, mostly-additive carry-over gaps in the network, block-storage, and
file/NAS domains: getter filter-field parameters, the VLAN idle-port guard design (prerequisite for
any VLAN live workflow), and small block/NAS documentation-of-behavior items. Blocked items are
tracked with their blockers, not implemented.

## Source TODOs / evidence

- `docs/network/TODO.md` Medium Priority — expose `Get-DMLif` (`IPV4ADDR`, `IPV6ADDR`, `HOMEPORTID`)
  and `Get-DMvLan` (`TAG`, `fatherDrvType`) filter params; VLAN live workflow **requires idle-port
  guard**; failover-group live member add/remove **blocked** (members are Ethernet/bond/VLAN ports,
  harness owns none).
- `docs/network/TODO.md` Deferred — bond member add/remove **no documented REST endpoint**.
- `docs/network/TODO.md` Future — routes/gateways, iSCSI portal/CHAP, NVMe-oF, per-port perf
  getters, LLDP neighbor getter (all `open`, no active phase).
- `docs/block-storage/TODO.md` — vStore-scoped mapping `-VstoreId` documentation; legacy-wrapper
  migration note; mapped-LUN-removal troubleshooting page.
- `docs/file-storage/nas-services.md` — CIFS/SMB, AD/LDAP-for-NAS, NFS service-level config **not
  implemented** (documented gaps).

## Current repository evidence

- `Get-DMLif.ps1` / `Get-DMvLan.ps1` are modified in the working tree (Phase 06 hardening) but do
  not yet expose the listed filter fields as parameters.
- `docs/network/safety-and-live-validation.md` describes the idle-port guard design; no guard code
  or `Network.AllowVlanLifecycle` gate exists yet.
- Failover-group workflow ships (`Tests/Integration/Private/Workflows/FailoverGroup.ps1`) but the
  live member add/remove step is intentionally absent (blocked).

## Scope

- Add the documented filter-field parameters to `Get-DMLif` and `Get-DMvLan` (prefer server-side
  `filter=` where the REST API documents it — see Phase 06 for the cross-domain filter item).
- Design + implement + unit-test the VLAN idle-port detection guard (no live run here).
- Block-storage: add the `-VstoreId` mapping guidance, the legacy-wrapper migration note, and the
  mapped-LUN-removal troubleshooting page (docs + any small parameter clarifications).
- Keep NAS-service and network-future items as tracked, evidence-backed gaps.

## Out of scope

- **Bond member add/remove** — blocked (no documented REST endpoint); do not send speculative bodies.
- **Failover-group live member add/remove** — blocked on the test-owned VLAN workflow + idle-port
  guard; no live claim here.
- Any VLAN **live** create/delete run → deferred to a supervised session (Phase 03-style) *after*
  the guard exists.
- Routes/gateways, iSCSI portal/CHAP, NVMe-oF, per-port perf, LLDP-neighbor getters — future feature
  branches, not this phase (list retained for planning only).

## Implementation tasks

1. `Get-DMLif`: add `-Ipv4Addr`/`-Ipv6Addr`/`-HomePortId` (map to documented filter fields).
2. `Get-DMvLan`: add `-Tag`/`-FatherDrvType`. Unit-test both with mocks.
3. VLAN idle-port guard: implement detection (port has no LIF/associations), unit-test it; leave the
   `Network.AllowVlanLifecycle` gate defined but **default off**, live run deferred.
4. Block/NAS docs: add the three block-storage items above; keep NAS "not implemented" statements
   accurate.

## Files likely to inspect

- `POSH-Oceanstor/Public/Get-DMLif.ps1`, `Get-DMvLan.ps1`
- `docs/network/safety-and-live-validation.md`, `docs/network/vlans.md`, `docs/network/TODO.md`
- `Tests/Integration/Private/Workflows/FailoverGroup.ps1`
- `docs/block-storage/mapping-views.md`, `docs/block-storage/TODO.md`, `docs/file-storage/*.md`

## Files likely to modify

- `POSH-Oceanstor/Public/Get-DMLif.ps1`, `Get-DMvLan.ps1` (new filter params)
- New guard helper (Private/) + its unit test; VLAN workflow scaffold (gated off)
- `Tests/Unit/Public/Get-Network.Tests.ps1` (or new test files), block/NAS docs

## Safety considerations

- Getter changes are read-only. The VLAN guard is design + unit tests only — **no live VLAN
  create/delete in this phase.** If a live VLAN run is ever scheduled, it follows the Phase 03
  strict rules (test-owned, verified-idle port, ID-tracked, cleanup in `finally`).

```powershell
# VLAN live workflow (deferred; internal planning reference only, do not run here)
$storageIP = '10.10.10.24'
$cred = Import-Clixml -Path "$env:USERPROFILE\.oceanstor\dm-creds.xml"
# -SkipCertificateCheck
```

## Testing strategy

- Mock-based unit tests for the new getter parameters (assert the filter is sent, not client-side
  post-filtering).
- Unit tests for the idle-port guard covering idle vs in-use vs unknown port states.

## Verification commands

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal
Select-String -Path .\POSH-Oceanstor\Public\Get-DMLif.ps1 -Pattern 'IPV4ADDR|HOMEPORTID'
```

## Dependencies

- The idle-port guard is a prerequisite for any future VLAN live workflow and for the failover-group
  live member step.
- Server-side `filter=` approach shared with Phase 06.

## Completion criteria

- `Get-DMLif`/`Get-DMvLan` expose the documented filter fields, unit-tested.
- VLAN idle-port guard implemented and unit-tested; gate defined but default off, no live run.
- Block/NAS documentation items added; blocked items remain tracked with blockers intact.

## Risks / notes

- Do not let the VLAN guard's existence be read as "VLAN live workflow is validated" — the live run
  remains a separate, supervised, deferred step.
