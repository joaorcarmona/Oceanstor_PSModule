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
        # PSScriptAnalyzer intermittently throws internal engine errors on its first invocation in a
        # fresh process (known races, e.g. "Object reference not set to an instance of an object" and
        # "You cannot have more than one dynamic module in each dynamic assembly"). Under
        # $ErrorActionPreference='Stop' any of these would abort the whole release gate at random.
        # Real analyzer *findings* are returned as data (never thrown), so any *exception* here is a
        # transient engine fault: retry a few times (the engine warms up after the first call) and
        # only rethrow after exhausting the retries, so a genuinely persistent failure still surfaces.
        $analyzerResults = $null
        $analyzerMaxAttempts = 5
        for ($analyzerAttempt = 1; $analyzerAttempt -le $analyzerMaxAttempts; $analyzerAttempt++) {
            try {
                $analyzerResults = Invoke-ScriptAnalyzer -Path $moduleRoot -Settings $settingsPath -Recurse -ErrorAction Stop
                break
            }
            catch {
                if ($analyzerAttempt -eq $analyzerMaxAttempts) { throw }
                Write-Warning "PSScriptAnalyzer threw a transient error (attempt $analyzerAttempt/$analyzerMaxAttempts): $($_.Exception.Message). Retrying."
                Start-Sleep -Milliseconds 250
            }
        }

        if ($analyzerResults) {
            $bySeverity = $analyzerResults | Group-Object Severity | Sort-Object Count -Descending
            Write-Host "PSScriptAnalyzer found $($analyzerResults.Count) issue(s):"
            $bySeverity | ForEach-Object { Write-Host "  $($_.Name): $($_.Count)" }
            $analyzerResults | ForEach-Object {
                Write-Host "  [$($_.Severity)] $($_.RuleName) - $($_.ScriptName):$($_.Line) - $($_.Message)"
            }

            if ($FailOnAnalyzerIssue) {
                # The release gate blocks only on Error-severity findings. Warning/Information
                # results are printed above for visibility but are deferred cleanup, not
                # release blockers (see todo/release-readiness-go-no-go.md section 3a).
                $errorFindings = @($analyzerResults | Where-Object { "$($_.Severity)" -eq 'Error' })
                if ($errorFindings.Count -gt 0) {
                    throw "PSScriptAnalyzer reported $($errorFindings.Count) Error-severity finding(s)."
                }
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
