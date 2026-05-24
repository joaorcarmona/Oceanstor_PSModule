[CmdletBinding()]
param(
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed',

    [string]$ResultPath
)

$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0.0 -ErrorAction Stop

$configuration = New-PesterConfiguration
$configuration.Run.Path = Join-Path -Path $PSScriptRoot -ChildPath 'Unit'
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = $Output

if ($ResultPath) {
    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ResultPath)
    $configuration.TestResult.OutputFormat = 'NUnitXml'
}

$result = Invoke-Pester -Configuration $configuration

if ($result.FailedCount -gt 0) {
    throw "Unit tests failed: $($result.FailedCount) failed, $($result.PassedCount) passed."
}

Write-Host "Unit tests passed: $($result.PassedCount)."
