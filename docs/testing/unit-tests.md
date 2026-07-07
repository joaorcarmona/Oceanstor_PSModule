# Unit Tests

Offline, mocked-REST validation of module behavior. No live array, no
credentials, no network access required.

## Where they live

```text
Tests/Unit/
  Public/    # one file per public cmdlet (or closely related group)
  Private/   # helper functions and internal classes
```

Each suite is designed to be independent — you should not need to run any
other suite first.

## Run all unit tests

The repository's own runner wraps `Invoke-Pester` with the project's Pester
version pin, optional PSScriptAnalyzer lint pass, and optional JUnit/coverage
output:

```powershell
./Tests/Invoke-UnitTests.ps1
```

Quieter output:

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal
```

Skip the PSScriptAnalyzer lint pass (it runs automatically if the module is
installed):

```powershell
./Tests/Invoke-UnitTests.ps1 -SkipAnalyzer
```

Write a JUnit XML report and code-coverage report (used by CI):

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal -ResultPath ./Reports/Pester.xml -CoveragePath ./Reports/Coverage.xml
```

With RTK for compressed output:

```powershell
C:\tools\rtk\rtk.exe ./Tests/Invoke-UnitTests.ps1
```

### Calling Pester directly

You can also invoke Pester directly against the `Unit` folder without the
wrapper script's lint pass or result-file handling:

```powershell
Invoke-Pester Tests/Unit
```

## Run one test file

```powershell
Invoke-Pester Tests/Unit/Public/Export-functions.Tests.ps1
```

## Run focused report-task tests

```powershell
Invoke-Pester Tests/Unit/Public/New-DMPerformanceReportTask.Tests.ps1
```

## Run focused performance tests

There is no single `*Performance*.Tests.ps1` glob wired into the repo — each
performance cmdlet has its own test file under `Tests/Unit/Public/`. Pass
`-Path` with an array of the files you want, or filter by name:

```powershell
Invoke-Pester -Path (Get-ChildItem Tests/Unit/Public/*Performance*.Tests.ps1, Tests/Unit/Public/*Capacity*.Tests.ps1, Tests/Unit/Public/*ReportTask*.Tests.ps1)
```

Or run the full suite and filter by test name with Pester's `-FullNameFilter`:

```powershell
Invoke-Pester Tests/Unit -FullNameFilter '*Performance*'
```

## Response fixtures

`Tests/Unit/Support/DMResponseFixtures.ps1` is a plain, dot-sourced function file
(no manifest, no `Export-ModuleMember` — same convention as
`Assert-DMWhatIfSafe.ps1`) that builds canonical OceanStor v6 REST-response
envelopes and sample objects, so individual test files don't have to
hand-roll `[pscustomobject]@{ error = ... }` shapes from scratch. It provides:

- `New-DMFixtureSuccessResponse [-Data]` / `New-DMFixtureErrorResponse -Code -Description`
  / `New-DMFixtureSessionExpiredResponse` (canonical code `1077939726`) /
  `New-DMFixtureEmptyResponse` — response envelopes.
- `New-DMFixturePagedResponse -Items -Start -End` / `New-DMFixtureIdenticalPageResponse -Items`
  — pagination and loop-protection test building blocks that mirror
  `Invoke-DMPagedRequest`'s exclusive-end window semantics.
- `New-DMFixtureLun`, `New-DMFixtureHost`, `New-DMFixtureFileSystem`,
  `New-DMFixtureNetworkObject`, `New-DMFixtureReplicationObject` — sanitized
  sample REST objects with override parameters for the fields tests commonly
  vary.
- `New-DMExactFilterResource` / `New-DMFuzzyFilterResource` / `New-DMRangeResourcePattern`
  — build the `resource?filter=PROP::value*`, `resource?filter=PROP:value*`,
  and `resource?range=[s-e]*` / `resource&range=[s-e]*` strings tests assert
  against with `-BeLike`, instead of hand-typing them (the range helper
  correctly picks `?` vs `&` based on whether the resource already has a
  query string).

**Sanitization rule**: every value in this file is an obviously-fake
placeholder — `POSHTEST-*` IDs/names, a made-up WWN (`2100000000000000`), a
made-up IQN (`iqn.1993-08.org.debian:01:poshtest`), and an RFC 5737
TEST-NET-1 address (`192.0.2.10`). Never copy a real lab hostname, serial,
WWN, IQN, NQN, MAC, or the lab array's IP into this file. A dedicated
sanitization test in `DMResponseFixtures.Tests.ps1` greps every fixture's
rendered output for the lab IP as a regression guard.

Dot-source it into a suite's test module the same way as any other shared
helper:

```powershell
. "$testRoot\..\Support\DMResponseFixtures.ps1"
```

Two pilot migrations show the pattern in practice: the LUN getter tests in
`Get-Storage.Tests.ps1` (`Get-DMlun`-specific `It` blocks) and the LUN
mutator tests in `Remove-DMLun.Tests.ps1`. This was a deliberate **pilot**,
not a mass migration — most existing test files still hand-roll their mock
objects, and that's fine. Migrate a file to the fixture library when you're
already touching it, not as a standalone sweep.

Fixtures are for fast, offline test-writing convenience only. They do not
replace the live integrity harness (see the "Safety and live validation"
page in each domain's docs) as ground truth for what the real array
actually returns.

## No live array required

Unit tests mock all REST calls (`Invoke-DeviceManager` and friends) — they
never open a connection to an array and never prompt for credentials.

## When to run before live tests

Always run the unit suite before a live integrity run. It catches regressions
in parsing, filtering, and object-shape logic far faster (seconds, not
minutes) and without touching a real array. See
[Integrity tests](integrity-tests.md) for the live layer.
