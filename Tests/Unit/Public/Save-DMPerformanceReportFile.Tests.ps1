BeforeDiscovery {
    $script:testModule = New-Module -Name SaveDMPerformanceReportFileTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Save-DMDeviceManagerFile { param($WebSession, [string]$Resource, [string]$OutFile, [switch]$ApiV2) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Save-DMPerformanceReportFile.ps1"

        Export-ModuleMember -Function Save-DMPerformanceReportFile
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name SaveDMPerformanceReportFileTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SaveDMPerformanceReportFileTestModule {
    Describe 'Save-DMPerformanceReportFile' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }
            $script:outPath = Join-Path $TestDrive 'report.zip'
            Remove-Item -LiteralPath $script:outPath -ErrorAction SilentlyContinue

            Mock Save-DMDeviceManagerFile {
                Set-Content -LiteralPath $OutFile -Value 'binary-content'
                return Get-Item -LiteralPath $OutFile
            }
        }

        It 'downloads via Save-DMDeviceManagerFile using the log_id and task_id resource' {
            Save-DMPerformanceReportFile -WebSession $script:session -LogId 'log-01' -TaskId 'task-01' -Path $script:outPath | Out-Null

            Should -Invoke Save-DMDeviceManagerFile -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'pms/report_task/file?log_id=log-01&task_id=task-01' -and
                $OutFile -eq $script:outPath -and
                $ApiV2 -eq $true
            }
        }

        It 'accepts LogId and TaskId via pipeline property name' {
            [pscustomobject]@{ LogId = 'log-02'; TaskId = 'task-02' } | Save-DMPerformanceReportFile -WebSession $script:session -Path $script:outPath | Out-Null

            Should -Invoke Save-DMDeviceManagerFile -Times 1 -Exactly -ParameterFilter {
                $Resource -eq 'pms/report_task/file?log_id=log-02&task_id=task-02'
            }
        }

        It 'throws when the destination already exists without -Force' {
            Set-Content -LiteralPath $script:outPath -Value 'existing'

            { Save-DMPerformanceReportFile -WebSession $script:session -LogId 'log-01' -TaskId 'task-01' -Path $script:outPath -ErrorAction Stop } | Should -Throw '*already exists*'

            Should -Invoke Save-DMDeviceManagerFile -Times 0 -Exactly
        }

        It 'overwrites the destination when -Force is specified' {
            Set-Content -LiteralPath $script:outPath -Value 'existing'

            Save-DMPerformanceReportFile -WebSession $script:session -LogId 'log-01' -TaskId 'task-01' -Path $script:outPath -Force | Out-Null

            Should -Invoke Save-DMDeviceManagerFile -Times 1 -Exactly
        }
    }
}
