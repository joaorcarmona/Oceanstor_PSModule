# Testing POSH-Oceanstor

This directory contains two complementary test layers:

- `Unit`: isolated Pester tests that mock REST calls and validate module behavior locally.
- `Integration`: live validation against an OceanStor array, including optional test-owned mutation workflows.

The recommended order is:

1. Run the unit suite.
2. Run read-only integration validation.
3. Review `Integration/IntegrityValidationConfig.psd1`.
4. Run mutation integration validation only against an appropriate test array.

The detailed test inventory and dependency order are documented in
`TestExecutionOrder.xml`.

## Prerequisites

- PowerShell 7 is recommended.
- Pester 5.0.0 or later is required for unit tests.
- Live integration tests require network access to an OceanStor array.
- Live credentials are requested interactively and are not stored in the
  configuration file.

Run commands from the repository root unless stated otherwise.

## Unit Tests

Unit tests are grouped by function or feature under `Unit/Private` and
`Unit/Public`. Each suite is designed to be independent: it should not require a
previous suite to run first.

Run the full unit suite:

```powershell
./Tests/Invoke-UnitTests.ps1
```

Use quieter output:

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal
```

Write a JUnit XML report, suitable for CI:

```powershell
./Tests/Invoke-UnitTests.ps1 -Output Normal -ResultPath ./Reports/Pester.xml
```

The GitHub Actions workflow uses the JUnit form above, writing into `Reports/`.

## Integration Methodology

The live integration runner is:

```text
Tests/Integration/Invoke-GetterIntegrityValidation.ps1
```

Every live run:

1. Prompts for credentials and creates an OceanStor WebSession.
2. Runs read-only getter validation.
3. Confirms returned object types when a type is expected.
4. Writes a JSON report.

When mutation mode is explicitly enabled, the runner also:

1. Creates resources with a generated test prefix and run timestamp.
2. Registers every created resource as test-owned.
3. Updates descriptions and renames supported resources immediately after creation.
4. Uses the renamed identities for dependent resources and associations.
5. Reads resources back to verify renames, creation, and associations.
6. Removes resources in reverse dependency order using their current names.
7. Writes a detailed mutation request trace.

Cleanup actions are registered as resources are created. Removal commands refuse
to modify resources that were not created and registered by the same run.

## Read-Only Integration

Use read-only mode first. It exercises getter functions without intentionally
creating, modifying, or deleting array resources.

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN'
```

Show one persistent output line for each completed check:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -ShowTestExecution
```

Hide interactive progress when redirecting console output:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -NoProgress
```

For lab arrays with self-signed certificates, opt out of TLS certificate
validation explicitly:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -SkipCertificateCheck
```

## Mutation Integration

Mutation mode is opt-in twice:

1. `AllowMutatingTests` must be `$true` in
   `Integration/IntegrityValidationConfig.psd1`.
2. The runner must be called with `-RunMutatingTests`.

Before running, review:

- `StoragePoolId`: existing pool used only as a placement target.
- `NamePrefix`: prefix for generated test-owned resource names.
- Enabled workflow sections: `Lun`, `LunGroup`, `Protection`, `Host`, `Nas`,
  `Mapping`, and `Initiators`.
- Initiator identities: supply only unused identities that may be created and
  deleted during the run.

Run the full configured create, verify, and cleanup workflow:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -SkipCertificateCheck `
    -ShowTestExecution
```

Run the extra multi-LUN pipeline regression coverage for `New-DMLun`,
`Set-DMLun`, `Add-DMLunToLunGroup`, `Remove-DMLunFromLunGroup`, and
`Remove-DMLun`:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -RunPipelineBatchCoverage `
    -SkipCertificateCheck `
    -ShowTestExecution
```

This creates three additional test-owned LUNs and can add noticeable runtime on
arrays where LUN creation or removal is slow. The same coverage can be enabled
in a custom configuration file with `LunGroup.EnablePipelineBatchCoverage =
$true`.

Enable the non-secure HyperCDP schedule workflow in the configuration file:

```powershell
HyperCDPSchedule = @{
    Enabled = $true
    FrequencyValueSeconds = 3600
    FrequencySnapshotCount = 2
}
```

This workflow creates a disabled block HyperCDP schedule, associates the
test-owned LUN, removes that association, toggles the schedule, and deletes it.
It does not use protection groups or secure snapshots.

Use a separate configuration file when testing a different array or subset of
workflows:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -ConfigurationPath './Tests/Integration/MyLabConfig.psd1' `
    -RunMutatingTests
```

## Network Cmdlet Coverage

Network getters (`Get-DMPortETH`, `Get-DMPortFc`, `Get-DMPortSAS`,
`Get-DMInterfaceModule`, `Get-DMPortBond`, `Get-DMvLan`, `Get-DMLif`,
`Get-DMFailoverGroup`, `Get-DMLLDPWorkingMode`) run as part of read-only
validation.

Network mutators (bond ports, VLANs, logical ports, failover groups, LLDP
working mode) have **no live mutation workflow by design**: they can affect
management access, data access, or failover behavior, so they are exercised by
unit tests only and surface in the live report as skipped/not executed rather
than passed. Do not add them to a workflow without following the test-owned
rules in `docs/network/safety-and-live-validation.md`.

## Output Files

The default live validation report is written to:

```text
Reports/getter-integrity-last-result.json
Reports/getter-integrity-last-result.md
```

Mutation mode additionally writes:

```text
Reports/mutation-trace-last-result.json
```

Override any location when retaining multiple runs (the target directory is created if missing):

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -ReportPath './Reports/lab-report.json' `
    -MutationLogPath './Reports/lab-mutation-trace.json'
```

## Status Meanings

- `Passed`: the command completed and returned the expected result shape.
- `NoData`: the command completed successfully, but the array had no matching
  objects.
- `NotRequested`: mutation mode was not requested.
- `NotConfigured`: the related workflow or required identity was not enabled.
- `NotExecuted`: the command was unnecessary for the current array state.
- `Blocked`: a prerequisite test-owned resource could not be created or found.
- `Failed`: the command raised an error.
- `UnexpectedType`: returned objects did not match the expected type.

After mutation validation, confirm:

- `Failed` is `0`.
- `Blocked` is `0`, unless a prerequisite is intentionally unavailable.
- `RemainingTestOwnedResources` is empty.

## Test Layout

```text
Tests/
  Invoke-UnitTests.ps1
  TestExecutionOrder.xml
  Unit/
  Integration/
    Invoke-GetterIntegrityValidation.ps1
    IntegrityValidationConfig.psd1
    Private/
      ValidationHelpers.ps1
      ReadValidation.ps1
      MutationValidation.ps1
      Reporting.ps1
      Workflows/
```
