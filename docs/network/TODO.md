# Network TODO

## Current Focus

- Stabilize the network lifecycle cmdlets added on this branch (bond ports,
  VLANs, LIFs, failover groups, LLDP working mode) and their unit coverage.

## Recently Completed

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

> Deduplication note: all High and Medium Priority items below are scoped for
> implementation in
> `todo/alpha-v1.0.0-post-merge-phase-06-network-hardening-and-workflows.md`,
> which re-verified each as still open against current code (2026-07-07).
> Status: `open` for all bullets in this section.

- Add `-WhatIf` regression tests for every network mutator asserting that no
  API call is made (currently none exist for this domain).
- Add a failover-group member getter (`failovergroup/associate` GET) so
  membership can be verified without inspecting LIFs.
- Config-gated, test-owned live workflow for failover groups (create → modify
  → member add/remove → delete by captured ID) in the integration harness,
  following the existing `Workflows/*.ps1` pattern.

## Medium Priority

- Server-side filters for `Get-DMLif` and `Get-DMvLan` (`-Name`/`-Id`), which
  currently return the full collection.
- Allow `Set-DMLif` to address a LIF by `-Id` alone (today `-Name` is
  mandatory). Verified still open: `Set-DMLif` still declares `-Name` as
  `Mandatory = $true` with no `-Id`-only path.
- Pipeline tests: `Get-DMPortBond | Remove-DMPortBond`,
  `Get-DMFailoverGroup | Set-DMFailoverGroup` property binding.
- Expose bond member add/remove after creation if the REST API supports it.

## Low Priority / Polish

- Friendly-name parameters instead of raw enums (`-BondPortType HostService`,
  `-AssociateObjectType EthernetPort`) with back-compat for numeric values.
- Decode more display fields on `OceanStorvLan` / `OceanStorPortBond`
  (running status, MTU) the way `OceanStorFailoverGroup` does.

## Testing and Validation

- Read-only network getters are covered by live read validation; keep new
  getters registered there as they are added.
- Network mutators must stay out of default live runs; any future live
  workflow must be config-gated and strictly test-owned (see
  [safety-and-live-validation.md](safety-and-live-validation.md)).
- VLAN live workflow (create/delete a tagged child on a verified-idle port)
  is possible in a dedicated lab but needs an idle-port detection guard first.

## Documentation

- Keep the per-domain pages in this folder in sync when parameters change.
- Add a worked NAS-provisioning walkthrough (failover group → LIF → share)
  once a member getter exists.

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
