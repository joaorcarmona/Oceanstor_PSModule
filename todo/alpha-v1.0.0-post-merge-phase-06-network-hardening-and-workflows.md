# alpha-v1.0.0 Post-Merge Phase 06 — Network Hardening and Safety-Sensitive Workflows

## Purpose

Harden the network cmdlet surface shipped on the merged network branch: add the missing
`-WhatIf` regression tests, the failover-group member getter, server-side filters, and
the config-gated, test-owned failover-group live workflow. Network is safety-sensitive:
a wrong mutation can sever management or data access.

## Source TODOs / evidence

- `docs/network/TODO.md` § High Priority — all three verified still open:
  - "Add `-WhatIf` regression tests for every network mutator … (currently none exist
    for this domain)" — confirmed: `Network-Actions.Tests.ps1` has zero WhatIf hits.
  - "Add a failover-group member getter (`failovergroup/associate` GET)" — confirmed:
    only `Add/Remove-DMFailoverGroupMember` touch that endpoint; no GET.
  - "Config-gated, test-owned live workflow for failover groups (create → modify →
    member add/remove → delete by captured ID)".
- § Medium Priority: server-side filters for `Get-DMLif`/`Get-DMvLan`; `Set-DMLif` by
  `-Id` alone; pipeline tests; bond member add/remove post-create (if REST supports it).
- § Low Priority: friendly-name enum parameters; more decoded display fields on
  `OceanStorvLan`/`OceanStorPortBond`.
- `docs/network/safety-and-live-validation.md` — routes/management-IP changes unsafe by
  default, not implemented; `Set-DMLLDPWorkingMode` never run live.
- `docs/network/logical-ports.md:83` — LIF lifecycle "not implemented in the integration
  harness yet".

Deduplication decision:
The network `-WhatIf` test work and the DR `-WhatIf` test work (Phase 07) are the same
pattern; whichever phase lands first should create the shared reusable assertion helper
(a `-ForEach`-driven "no API call under -WhatIf" Pester pattern), and the other consumes
it. Routes/gateways, iSCSI portal/CHAP, NVMe-oF, LLDP neighbors are future feature
branches per the TODO — inventoried in Phase 01, not planned here.

## Scope

- [Tests] `-WhatIf` regression tests for every network mutator (`New/Set/Remove-DMPortBond`,
  `New/Set/Remove-DMvLan`, `New/Set/Remove-DMLif`, `New/Set/Remove-DMFailoverGroup`,
  `Add/Remove-DMFailoverGroupMember`, `Set-DMLLDPWorkingMode`) asserting zero
  `Invoke-DeviceManager` calls under `-WhatIf`. Build the shared assertion helper here.
- [Code] `Get-DMFailoverGroupMember` (or parameter set on `Get-DMFailoverGroup`) using
  `failovergroup/associate` GET; typed output; registered in `ReadValidation.ps1` and
  `ModuleCoverage.psd1`.
- [Code] Server-side `filter=` support (`-Name`/`-Id`) on `Get-DMLif` and `Get-DMvLan`,
  following the repo's exact/fuzzy `::`/`:` convention with client-side `-Like` re-check
  (confirm each filter field in the REST reference first).
- [Code] `Set-DMLif`: allow addressing by `-Id` alone (today `-Name` is mandatory).
- [Tests] Pipeline property-binding tests: `Get-DMPortBond | Remove-DMPortBond`,
  `Get-DMFailoverGroup | Set-DMFailoverGroup`.
- [Code] Investigate bond member add/remove after creation in the REST reference;
  implement only if documented.
- [Code] New `Tests/Integration/Private/Workflows/FailoverGroup.ps1`: config-gated,
  test-owned lifecycle (create → modify → member add/remove → delete by captured ID),
  existing `Workflows/*.ps1` pattern. Member add/remove must target a LIF the workflow
  itself created, or be skipped when no test-owned LIF exists.
- [Live-validation planning] VLAN live workflow (tagged child on a verified-idle port)
  requires an idle-port detection guard first — design the guard; do not enable the
  workflow until the guard provably refuses non-idle ports.

## Out of scope

- Physical port mutation, management IP/route changes, live `Set-DMLLDPWorkingMode` —
  Not Planned / Unsafe by Default; keep it that way.
- Routes/iSCSI/NVMe-oF/LLDP-neighbor feature branches.
- Friendly-name enums and extra display fields (polish backlog; pull in only if time
  permits after the safety items).

## Implementation tasks

- [Tests] Shared WhatIf assertion helper + coverage for all network mutators.
- [Code] Member getter; filters; `-Id`-only `Set-DMLif`; optional bond-member ops.
- [Tests] Pipeline binding tests; unit tests for all new parameters/getter.
- [Code] Failover-group workflow with gates (`Network.Enabled`,
  `Network.AllowFailoverGroupLifecycle` — align names with existing config).
- [Safety review] Sweep all network mutators: `SupportsShouldProcess` present,
  in-place modify/delete use `ConfirmImpact = 'High'`, bodies built with
  `ConvertTo-DMRequestBody`, object-ID-based deletion only.
- [Docs-only] Update `docs/network/*.md` pages and TODO; add the NAS-provisioning
  walkthrough (failover group → LIF → share) once the member getter exists.
- [Live-validation planning] Runbook for the gated failover-group workflow on the lab
  array (internal planning may use `$storageIP = '10.10.10.24'`; `-SkipCertificateCheck`
  required); no live run during development.

## Files likely to inspect

- `POSH-Oceanstor/Public/*PortBond*`, `*vLan*`, `*DMLif*`, `*FailoverGroup*`, `*LLDP*`
- `Tests/Unit/Public/Network-Actions.Tests.ps1`, `Get-Network.Tests.ps1`
- `Tests/Integration/Private/Workflows/*.ps1`, `ReadValidation.ps1`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md` (associate GET, filter fields,
  bond member endpoints)

## Files likely to modify

- New member-getter cmdlet + class updates; `Get-DMLif.ps1`, `Get-DMvLan.ps1`,
  `Set-DMLif.ps1`
- `Network-Actions.Tests.ps1` (+ new WhatIf helper under `Tests/Unit/` support files)
- New `Workflows/FailoverGroup.ps1`; `Invoke-GetterIntegrityValidation.ps1`
  (registration + dot-source whitelist); `ReadValidation.ps1`; `ModuleCoverage.psd1`
- `POSH-Oceanstor.psd1` (new export); `docs/network/*.md`

## Safety considerations

- Failover-group workflow: unique test prefix, immediate ID capture, cleanup registered
  immediately, `finally` cleanup, delete by captured ID, loud failed-cleanup reporting.
- Never touch pre-existing failover groups, LIFs, VLANs, bonds, ports, routes, or
  management addressing. No name-pattern cleanup.
- The member add/remove step must never move a member that carries live traffic — only
  test-owned members.
- VLAN workflow stays disabled until the idle-port guard exists and is itself tested.

## Testing strategy

1. Unit: WhatIf suite, new getter/filter/pipeline tests, full suite green.
2. Harness dry run with all network gates off → `NotConfigured` reporting only.
3. Later, human-scheduled gated live run of the failover-group workflow per runbook.

## Verification commands

```powershell
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
git diff --check; git diff --stat
```

## Dependencies

- Phase 01. Phase 02 recommended first (correct `NotConfigured`/`NotRequested` labels for
  the new workflow's commands). Shares the WhatIf helper with Phase 07.

## Completion criteria

- Every network mutator has a passing no-API-call-under-WhatIf test.
- Member getter shipped + registered in live read validation.
- Failover-group workflow merged, gated off by default; runbook written.
- `docs/network/TODO.md` High/Medium sections updated to match.

## Risks / notes

- `failovergroup/associate` GET response shape must be confirmed against the REST
  reference — do not assume symmetry with the POST/DELETE bodies.
- Server-side filter fields on `lif`/`vlan` endpoints may be undocumented; if so, keep
  client-side filtering and record the finding instead of sending speculative filters.
