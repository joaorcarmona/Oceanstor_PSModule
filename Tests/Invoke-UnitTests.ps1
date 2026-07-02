[CmdletBinding()]
param(
    [ValidateSet('None', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed',

    [string]$ResultPath,

    [string]$CoveragePath,

    [switch]$SkipAnalyzer,

    [switch]$FailOnAnalyzerIssue
)

$ErrorActionPreference = 'Stop'

if (-not $SkipAnalyzer) {
    $analyzerModule = Get-Module -Name PSScriptAnalyzer -ListAvailable | Select-Object -First 1
    if ($null -eq $analyzerModule) {
        Write-Warning 'PSScriptAnalyzer is not installed locally; skipping lint pass (CI still runs the full rule set). Install with: Install-Module PSScriptAnalyzer -Scope CurrentUser'
    }
    else {
        Import-Module PSScriptAnalyzer -ErrorAction Stop
        $moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\POSH-Oceanstor'
        $settingsPath = Join-Path -Path $PSScriptRoot -ChildPath '..\PSScriptAnalyzerSettings.psd1'
        $analyzerResults = Invoke-ScriptAnalyzer -Path $moduleRoot -Settings $settingsPath -Recurse

        if ($analyzerResults) {
            $bySeverity = $analyzerResults | Group-Object Severity | Sort-Object Count -Descending
            Write-Host "PSScriptAnalyzer found $($analyzerResults.Count) issue(s):"
            $bySeverity | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
            $analyzerResults | ForEach-Object {
                Write-Host "  [$($_.Severity)] $($_.RuleName) - $($_.ScriptName):$($_.Line) - $($_.Message)"
            }

            if ($FailOnAnalyzerIssue) {
                throw "PSScriptAnalyzer reported $($analyzerResults.Count) issue(s)."
            }
        }
        else {
            Write-Host 'PSScriptAnalyzer: no issues found.'
        }
    }
}

# Capped below 6.0 so a future Pester major release can't be picked up silently and break
# CI on breaking-change assumptions; bump the ceiling deliberately after validating against it.
Import-Module Pester -MinimumVersion 5.0.0 -MaximumVersion 5.99.99 -ErrorAction Stop

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

if ($CoveragePath) {
    $resolvedCoveragePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CoveragePath)
    $coverageDirectory = Split-Path -Path $resolvedCoveragePath -Parent

    if (-not (Test-Path -LiteralPath $coverageDirectory)) {
        $null = New-Item -Path $coverageDirectory -ItemType Directory -Force
    }

    $moduleRoot = Join-Path -Path $PSScriptRoot -ChildPath '..\POSH-Oceanstor'
    $configuration.CodeCoverage.Enabled = $true
    $configuration.CodeCoverage.Path = @(
        (Join-Path $moduleRoot 'Public')
        (Join-Path $moduleRoot 'Private')
    )
    $configuration.CodeCoverage.OutputPath = $resolvedCoveragePath
    $configuration.CodeCoverage.OutputFormat = 'JaCoCo'
    $configuration.CodeCoverage.RecursePaths = $true
}

$result = Invoke-Pester -Configuration $configuration

if ($null -eq $result) {
    throw 'Pester did not return a test result.'
}

if ($CoveragePath -and $result.CodeCoverage) {
    $cc = $result.CodeCoverage
    $pct = if ($cc.CommandsAnalyzedCount -gt 0) {
        [math]::Round(($cc.CommandsExecutedCount / $cc.CommandsAnalyzedCount) * 100, 1)
    } else { 0 }
    Write-Host "Code coverage: $pct% ($($cc.CommandsExecutedCount)/$($cc.CommandsAnalyzedCount) commands)."
}

if ($result.Result -ne 'Passed' -or $result.FailedCount -gt 0) {
    throw "Unit tests failed: $($result.FailedCount) failed, $($result.PassedCount) passed."
}

Write-Host "Unit tests passed: $($result.PassedCount)."
