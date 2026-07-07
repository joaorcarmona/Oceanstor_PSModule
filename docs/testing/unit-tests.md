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

## No live array required

Unit tests mock all REST calls (`Invoke-DeviceManager` and friends) — they
never open a connection to an array and never prompt for credentials.

## When to run before live tests

Always run the unit suite before a live integrity run. It catches regressions
in parsing, filtering, and object-shape logic far faster (seconds, not
minutes) and without touching a real array. See
[Integrity tests](INTEGRITY-TESTS.md) for the live layer.
