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
        It 'classifies global system-management mutators as SkippedUnsafe when mutating tests are requested' {
            $script:RunMutatingTests = $true
            # AllowMutatingTests stays $false so no workflow (and no API call) can run.

            Invoke-MutationValidation

            foreach ($mutator in @('Set-DMSnmpConfig', 'Set-DMSnmpSecurityPolicy', 'Set-DMSnmpCommunity', 'Set-DMSyslogNotification', 'Set-DMTimeZone', 'Set-DMutcTime', 'Lock-DMLocalUser', 'Reset-DMLocalUserPassword')) {
                $rows = @($checks | Where-Object Name -EQ $mutator)
                $rows.Count | Should -Be 1 -Because "$mutator must be represented exactly once"
                $rows[0].Status | Should -Be 'SkippedUnsafe' -Because "$mutator has no safe mutation workflow"
                $rows[0].Error | Should -BeLike '*not exercised by the integrity harness unless a dedicated safe workflow exists*'
            }

            # Commands covered by the config-gated SystemManagement workflow are no
            # longer unconditionally SkippedUnsafe.
            foreach ($mutator in @('New-DMSnmpTrapServer', 'New-DMSnmpUsmUser', 'Add-DMSyslogServer', 'New-DMLocalUser', 'New-DMRole')) {
                @($checks | Where-Object { $_.Name -eq $mutator -and $_.Status -eq 'SkippedUnsafe' }).Count | Should -Be 0 -Because "$mutator belongs to the SystemManagement workflow"
            }
        }

        It 'classifies system-management mutators as SkippedUnsafe in read-only runs while workflow commands stay NotRequested' {
            Invoke-MutationValidation

            @($checks | Where-Object Name -EQ 'Set-DMSyslogNotification')[0].Status | Should -Be 'SkippedUnsafe'
            @($checks | Where-Object Name -EQ 'New-DMLun')[0].Status | Should -Be 'NotRequested'
        }

        It 'reports SystemManagement workflow commands as NotRequested in read-only runs' {
            Invoke-MutationValidation

            foreach ($commandName in @('New-DMSnmpTrapServer', 'Set-DMSnmpTrapServer', 'Test-DMSnmpTrapServer', 'Remove-DMSnmpTrapServer', 'New-DMSnmpUsmUser', 'Add-DMSyslogServer', 'Remove-DMSyslogServer', 'New-DMLocalUser', 'New-DMRole', 'Remove-DMRole')) {
                $rows = @($checks | Where-Object Name -EQ $commandName)
                $rows.Count | Should -Be 1 -Because "$commandName must be represented exactly once"
                $rows[0].Status | Should -Be 'NotRequested'
                $rows[0].Error | Should -BeLike '*SystemManagement gates*'
            }
        }
    }

    Context 'SystemManagement workflow gate classification' {
        It 'reports every SystemManagement workflow command NotConfigured when the master gate is off' {
            $script:configuration = @{ AllowMutatingTests = $true; SystemManagement = @{ Enabled = $false } }

            . $script:SystemManagementMutationWorkflow

            foreach ($commandName in @($script:SystemManagementWorkflowCommandGates.Values | ForEach-Object { $_ })) {
                $rows = @($checks | Where-Object Name -EQ $commandName)
                $rows.Count | Should -Be 1 -Because "$commandName must be represented exactly once"
                $rows[0].Status | Should -Be 'NotConfigured'
                $rows[0].Error | Should -BeLike '*SystemManagement.Enabled*'
            }
        }

        It 'reports every SystemManagement workflow command NotConfigured when the config has no SystemManagement section' {
            $script:configuration = @{ AllowMutatingTests = $true }

            . $script:SystemManagementMutationWorkflow

            foreach ($commandName in @($script:SystemManagementWorkflowCommandGates.Values | ForEach-Object { $_ })) {
                @($checks | Where-Object Name -EQ $commandName)[0].Status | Should -Be 'NotConfigured'
            }
        }

        It 'keeps every command NotConfigured and calls no API when the master gate is on but all sub-gates are off' {
            $script:configuration = @{
                AllowMutatingTests = $true
                SystemManagement   = @{
                    Enabled                 = $true
                    AllowSnmpTrapServer     = $false
                    AllowSnmpUsmUser        = $false
                    AllowSyslogServer       = $false
                    AllowLocalUserLifecycle = $false
                }
            }

            . $script:SystemManagementMutationWorkflow

            @($checks | Where-Object Status -NE 'NotConfigured').Count | Should -Be 0 -Because 'no sub-workflow may execute anything while its gate is off'
            @($checks | Where-Object Name -EQ 'New-DMLocalUser')[0].Error | Should -BeLike '*SECURITY-SENSITIVE*'
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

    Context 'Write-ValidationReport NotRequested vs Blocked routing' {
        BeforeEach {
            $script:RunMutatingTests = $true
            $script:configuration = @{ AllowMutatingTests = $true }
            $script:IncludePerformance = $false
            $script:IncludePerformanceHistory = $false
            $script:IncludeCapacityHistory = $false
            $script:IncludeExcelPerformance = $false
            $script:AllowMonitoringMutation = $false
        }

        It 'reports performance, history, capacity and excel commands as NotRequested on a mutating run without their switches' {
            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            foreach ($commandName in @(
                'Get-DMPerformance', 'Get-DMSystemPerformance', 'Get-DMPerformanceHistory',
                'Get-DMCapacityHistory', 'Export-DMStorageToExcel', 'New-DMPerformanceReportTask'
            )) {
                $row = @($report.Checks | Where-Object Name -EQ $commandName)[0]
                $row.Status | Should -Be 'NotRequested' -Because "$commandName is gated by an opt-in switch that was not passed"
                $row.Error | Should -BeLike '*opt-in switch*' -Because "$commandName's reason must name the missing switch"
            }

            @($report.Checks | Where-Object Name -EQ 'New-DMLun')[0].Status | Should -Be 'Blocked' -Because 'New-DMLun is not part of any opt-in domain'
        }

        It 'requires both IncludePerformance and AllowMonitoringMutation before treating monitoring mutators as requested' {
            $script:IncludePerformance = $true
            $script:AllowMonitoringMutation = $false

            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            @($report.Checks | Where-Object Name -EQ 'Enable-DMPerformanceMonitoring')[0].Status | Should -Be 'NotRequested'
            @($report.Checks | Where-Object Name -EQ 'Disable-DMPerformanceMonitoring')[0].Status | Should -Be 'NotRequested'
            @($report.Checks | Where-Object Name -EQ 'Get-DMPerformance')[0].Status | Should -Be 'Blocked' -Because 'IncludePerformance is set, so realtime commands are requested; an unrepresented one is a real gap'
        }

        It 'does not mark performance commands NotRequested once their switch is passed' {
            $script:IncludePerformance = $true
            $script:AllowMonitoringMutation = $true

            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            @($report.Checks | Where-Object Name -EQ 'Get-DMPerformance')[0].Status | Should -Be 'Blocked'
            @($report.Checks | Where-Object Name -EQ 'Enable-DMPerformanceMonitoring')[0].Status | Should -Be 'Blocked'
        }

        It 'leaves a genuine prerequisite failure Blocked even inside a requested domain' {
            $script:IncludePerformanceHistory = $true
            $checks.Add([pscustomobject]@{
                Name         = 'New-DMPerformanceReportTask:Lifecycle'
                Category     = 'Mutation'
                Status       = 'Failed'
                DurationMs   = 1.0
                Count        = 0
                ExpectedType = 'OceanstorPerformanceReportTask'
                ActualTypes  = @()
                Error        = 'Report task creation failed'
            })

            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            @($report.Checks | Where-Object Name -EQ 'Get-DMPerformanceReportTask')[0].Status | Should -Be 'Blocked' -Because 'IncludePerformanceHistory was requested but the prerequisite task never got created'
        }

        It 'does not convert SkippedUnsafe results into NotRequested or Blocked' {
            Add-SkippedResult -Name @('New-DMRole') -Status 'SkippedUnsafe' -Reason 'No safe mutation workflow exists.'

            $null = Write-ValidationReport

            $report = Get-Content -LiteralPath $ReportPath -Raw | ConvertFrom-Json
            @($report.Checks | Where-Object Name -EQ 'New-DMRole')[0].Status | Should -Be 'SkippedUnsafe'
        }
    }
}
