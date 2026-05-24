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
    $resolvedResultPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ResultPath)
    $resultDirectory = Split-Path -Path $resolvedResultPath -Parent

    if (-not (Test-Path -LiteralPath $resultDirectory)) {
        $null = New-Item -Path $resultDirectory -ItemType Directory -Force
    }

    $configuration.TestResult.Enabled = $true
    $configuration.TestResult.OutputPath = $resolvedResultPath
    $configuration.TestResult.OutputFormat = 'JUnitXml'
}

$result = Invoke-Pester -Configuration $configuration

if ($null -eq $result) {
    throw 'Pester did not return a test result.'
}

if ($result.Result -ne 'Passed' -or $result.FailedCount -gt 0) {
    throw "Unit tests failed: $($result.FailedCount) failed, $($result.PassedCount) passed."
}

Write-Host "Unit tests passed: $($result.PassedCount)."
