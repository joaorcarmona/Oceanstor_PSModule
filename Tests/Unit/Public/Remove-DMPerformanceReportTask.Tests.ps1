BeforeDiscovery {
    $script:testModule = New-Module -Name RemoveDMPerformanceReportTaskTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData, [switch]$ApiV2) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPerformanceReportTask.ps1"

        Export-ModuleMember -Function Remove-DMPerformanceReportTask, Get-DMPerformanceReportTask
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name RemoveDMPerformanceReportTaskTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope RemoveDMPerformanceReportTaskTestModule {
    Describe 'Remove-DMPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }

            Mock Invoke-DeviceManager {
                if ($Method -eq 'GET') {
                    if ($Resource -match 'range=\[0-') {
                        return [pscustomobject]@{
                            data = @(
                                [pscustomobject]@{ id = '1'; name = 'lun-history'; content = @() }
                            )
                        }
                    }
                    return [pscustomobject]@{ data = @() }
                }
                return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
            }
        }

        It 'DELETEs pms/report_task/{id} when resolved by Name' {
            Remove-DMPerformanceReportTask -Name 'lun-history' -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Resource -eq 'pms/report_task/1' -and $ApiV2 -eq $true
            }
        }

        It 'DELETEs pms/report_task/{id} when resolved by Id' {
            Remove-DMPerformanceReportTask -Id '1' -Confirm:$false

            Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Resource -eq 'pms/report_task/1' -and $ApiV2 -eq $true
            }
        }

        It 'does not call Invoke-DeviceManager DELETE when -WhatIf is specified' {
            Remove-DMPerformanceReportTask -Name 'lun-history' -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }

        It 'rejects an unknown Name at parameter binding' {
            { Remove-DMPerformanceReportTask -Name 'does-not-exist' -Confirm:$false } | Should -Throw
        }
    }
}
