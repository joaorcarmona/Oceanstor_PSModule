# alpha-v1.0.0 Post-Merge Phase 03 — System Management Cmdlet Gaps (Read/Parameter Polish)

## Purpose

Close the small, low-risk, code-verified system-management gaps that need no live
mutation: `Get-DMAlarm` date/range filtering, syslog named parameters, and typed output
for `Get-DMdnsServer`. These are "quick wins" that improve daily operator use before the
larger mutation-workflow and certificate phases.

## Source TODOs / evidence

- `docs/system-management/TODO.md`:
  - "`Get-DMAlarm` date/range filtering." — verified open: `Get-DMAlarm.ps1` currently
    exposes only `-AlarmStatus` (`Unrecovered`/`Cleared`/`Recovered`).
  - "syslog severity/facility/port" named parameters — verified open:
    `Set-DMSyslogNotification.ps1` has no such parameters.
  - Low priority: "Typed output class `Get-DMdnsServer`." — verified open: OutputType is
    `[hashtable]`, no `OceanStor*` class.
- `docs/system-management/dns.md`, `docs/system-management/syslog.md`,
  `docs/system-management/alarms-and-events.md` — pages to keep in sync.

Deduplication decision:
Alarm **acknowledge/clear** and event **query** cmdlets are listed in the same TODO but
involve new mutating surface and REST research; they are deferred to Phase 04 (workflow
design decides whether ack/clear is safe) rather than duplicated here. This phase touches
only existing getters/setters' parameters and output typing.

## Scope

- [Code] `Get-DMAlarm`: add `-StartTime`/`-EndTime` (DateTime, converted to epoch) and/or
  a `-Last <timespan>` convenience, using the documented `historyalarm`/`alarm` filter
  fields from `OceanStor Dorado 6.1.6 REST Interface Reference.md`. Preserve the existing
  exact double-colon `alarmStatus::` filter fix and pagination via
  `Invoke-DMPagedRequest`.
- [Code] `Set-DMSyslogNotification` (and `Add-DMSyslogServer` if the endpoint supports
  per-server settings): named `-Severity`, `-Facility`, `-Port` parameters with
  `ValidateSet`/`ValidateRange` mapped to Huawei numeric codes via
  `ConvertTo-DMRequestBody`-style gating (only transmit bound parameters).
- [Code] `Get-DMdnsServer`: introduce a typed output class (string-form
  `[OutputType('OceanStorDnsServer')]` — class literals do not resolve on plain import,
  known repo constraint), register it in `Tests/ModuleCoverage.psd1`, add a format view
  if the repo convention calls for one.
- [Tests] Unit tests: date-to-epoch conversion, filter string composition (assert
  `::` exact form where applicable), parameter validation failures, new class shape;
  update any `ReadValidation.ps1` expected-type entry for `Get-DMdnsServer`.
- [Docs-only] Update the three domain pages with the new parameters and examples using
  the sanitized pattern (`$storageIP = 'StorageIP'`).

## Out of scope

- New alarm/event mutators (ack/clear) — Phase 04.
- LDAP/AD and Email/SMTP — Phase 04/backlog (research-heavy, mutating).
- Any live run.

## Implementation tasks

- [Code] Confirm each REST filter/parameter against the 6.1.6 reference before adding it;
  do not invent filter fields.
- [Code] Implement the three cmdlet changes above; keep public parameter surface
  backward-compatible (new optional parameters only).
- [Tests] Extend `Tests/Unit/Public/Get-Hardware.Tests.ps1` (alarm),
  the syslog/system-configuration test files, and DNS tests; keep mock resource-string
  assertions wildcard-tolerant of `range=` segments (established pattern).
- [Safety review] `Set-DMSyslogNotification` keeps `SupportsShouldProcess`; changing
  output typing on `Get-DMdnsServer` must not break `Set-DMdnsServer` round-trips.
- [Docs-only] Sync `dns.md`, `syslog.md`, `alarms-and-events.md`; move the closed bullets
  in `docs/system-management/TODO.md` to Recently Completed.

## Files likely to inspect

- `POSH-Oceanstor/Public/Get-DMAlarm.ps1`, `Set-DMSyslogNotification.ps1`,
  `Add-DMSyslogServer.ps1`, `Get-DMdnsServer.ps1`, `Set-DMdnsServer.ps1`
- `OceanStor Dorado 6.1.6 REST Interface Reference.md`
- `POSH-Oceanstor/Private/class-*.ps1` (class conventions), `POSH-Oceanstor/Formats/`

## Files likely to modify

- The four public cmdlets above; one new `Private/class-OceanStorDnsServer.ps1`
- `Tests/ModuleCoverage.psd1`, affected unit test files
- `POSH-Oceanstor.psd1` only if a format file is added (`FormatsToProcess`)
- `docs/system-management/{dns,syslog,alarms-and-events}.md`, `TODO.md`

## Safety considerations

- Getters only gain filters — no mutation risk.
- Syslog setter gains parameters but no new live testing; it stays `SkippedUnsafe` in
  live runs (global setting, no safe undo).
- New Private class file must be added to the dot-source whitelist in
  `Tests/Integration/Invoke-GetterIntegrityValidation.ps1` or live-only failures follow
  (documented repo quirk).

## Testing strategy

1. Targeted unit tests per changed cmdlet first.
2. Full unit suite via the repo wrapper.
3. `Import-Module` + `Get-Command` smoke to confirm typed output resolves on plain import.

## Verification commands

```powershell
Test-ModuleManifest .\POSH-Oceanstor\POSH-Oceanstor.psd1
Import-Module .\POSH-Oceanstor\POSH-Oceanstor.psd1 -Force
Get-Command -Module POSH-Oceanstor
C:\tools\rtk\rtk.exe .\Tests\Invoke-UnitTests.ps1 -SkipAnalyzer -Output Normal
git diff --check; git diff --stat
```

## Dependencies

- Phase 01 (confirmed-open status). Independent of Phase 02.

## Completion criteria

- All three gaps closed with unit coverage; `docs/system-management/TODO.md` updated.
- Zero regressions in the full unit suite; ScriptAnalyzer clean on changed files.

## Risks / notes

- The alarm endpoint's time fields must be confirmed in the REST reference; the earlier
  `alarmStatus` fuzzy-match bug shows this endpoint punishes assumptions — always use
  `::` exact filters for enum/numeric fields.
- Changing `Get-DMdnsServer` output from hashtable to a class is a minor breaking change
  for scripts indexing into the hashtable; document it in `RELEASE_NOTES.md` at release
  time (Phase 11).
