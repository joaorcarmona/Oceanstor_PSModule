BeforeAll {
    . "$PSScriptRoot\..\..\Integration\Private\ValidationHelpers.ps1"
    . "$PSScriptRoot\..\..\Integration\Private\MutationValidation.ps1"
    . "$PSScriptRoot\..\..\Integration\Private\Reporting.ps1"

    function Set-DMValidationRequestTraceContext {
        param([string]$Name, [string]$Category)
    }
}

Describe 'Integrity harness status classification' {
    BeforeEach {
        $script:NoProgress = $true
        $script:ShowTestExecution = $false
        $script:checks = [System.Collections.Generic.List[object]]::new()
        $script:owned = @{}
        $script:excludedCommands = @()
        $script:moduleRoot = (Resolve-Path "$PSScriptRoot\..\..\..\POSH-Oceanstor").Path
        $script:configuration = @{ AllowMutatingTests = $false }
        $script:RunMutatingTests = $false
        $script:Hostname = 'unit-test-array'
        $script:runStartedAt = Get-Date
        $script:runId = 'unittest'
        $script:mutationRequests = [System.Collections.Generic.List[object]]::new()
        $script:ReportPath = Join-Path $TestDrive 'report.json'
        $script:MarkdownReportPath = Join-Path $TestDrive 'report.md'
        $script:MutationLogPath = Join-Path $TestDrive 'mutation.json'
    }

    Context 'Invoke-MutationValidation system-management classification' {
        It 'classifies system-management mutators as SkippedUnsafe when mutating tests are requested' {
            $script:RunMutatingTests = $true
            # AllowMutatingTests stays $false so no workflow (and no API call) can run.

            Invoke-MutationValidation

            foreach ($mutator in @('New-DMRole', 'Set-DMSnmpConfig', 'Set-DMTimeZone', 'Set-DMutcTime', 'New-DMLocalUser')) {
                $rows = @($checks | Where-Object Name -EQ $mutator)
                $rows.Count | Should -Be 1 -Because "$mutator must be represented exactly once"
                $rows[0].Status | Should -Be 'SkippedUnsafe' -Because "$mutator has no safe mutation workflow"
                $rows[0].Error | Should -BeLike '*not exercised by the integrity harness unless a dedicated safe workflow exists*'
            }
        }

        It 'classifies system-management mutators as SkippedUnsafe in read-only runs while workflow commands stay NotRequested' {
            Invoke-MutationValidation

            @($checks | Where-Object Name -EQ 'Set-DMSyslogNotification')[0].Status | Should -Be 'SkippedUnsafe'
            @($checks | Where-Object Name -EQ 'New-DMLun')[0].Status | Should -Be 'NotRequested'
        }
    }

    Context 'Write-ValidationReport fallback' {
        It 'keeps Blocked for unrepresented workflow commands without blocking skipped or passed checks' {
            $script:RunMutatingTests = $true
            $script:configuration = @{ AllowMutatingTests = $true }
            $checks.Add([pscustomobject]@{
                Name         = 'Get-DMTimeZone'
                Category     = 'Read'
                Status       = 'Passed'
                DurationMs   = 1.0
                Count        = 1
                ExpectedType = 'PSCustomObject'
                ActualTypes  = @('PSCustomObject')
                Error        = $null
            })
            Add-SkippedResult -Name @('New-DMRole') -Status 'SkippedUnsafe' -Reason 'No safe mutation workflow exists.'

            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            @($report.Checks | Where-Object Name -EQ 'New-DMLun')[0].Status | Should -Be 'Blocked'
            @($report.Checks | Where-Object Name -EQ 'New-DMRole')[0].Status | Should -Be 'SkippedUnsafe'
            @($report.Checks | Where-Object Name -EQ 'Get-DMTimeZone')[0].Status | Should -Be 'Passed'
        }

        It 'uses NotExecuted instead of Blocked for unrepresented commands in read-only runs' {
            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            @($report.Checks | Where-Object Name -EQ 'New-DMLun')[0].Status | Should -Be 'NotExecuted'
        }
    }
}
