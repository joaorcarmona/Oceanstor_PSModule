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
./Tests/Invoke-UnitTests.ps1 -Output Normal -ResultPath ./TestResults/Pester.xml
```

The GitHub Actions workflow uses the JUnit form above.

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
3. Modifies only resources registered by the current run.
4. Reads resources back to verify creation and associations.
5. Removes resources in reverse dependency order.
6. Writes a detailed mutation request trace.

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
    -ShowTestExecution
```

Use a separate configuration file when testing a different array or subset of
workflows:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -ConfigurationPath './Tests/Integration/MyLabConfig.psd1' `
    -RunMutatingTests
```

## Output Files

The default live validation report is:

```text
Tests/Integration/getter-integrity-last-result.json
```

Mutation mode additionally writes:

```text
Tests/Integration/mutation-trace-last-result.json
```

Override either location when retaining multiple runs:

```powershell
./Tests/Integration/Invoke-GetterIntegrityValidation.ps1 `
    -Hostname 'IP_or_FQDN' `
    -RunMutatingTests `
    -ReportPath './TestResults/lab-report.json' `
    -MutationLogPath './TestResults/lab-mutation-trace.json'
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
