BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMPerformanceReportTaskTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager { param($WebSession, $Method, $Resource, $BodyData, [switch]$ApiV2) }
        function Get-DMApiErrorMessage { param($Code, $Description) return "$Code $Description" }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorPerformanceReportTask.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMPerformanceReportTask.ps1"

        Export-ModuleMember -Function Get-DMPerformanceReportTask
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMPerformanceReportTaskTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMPerformanceReportTaskTestModule {
    Describe 'Get-DMPerformanceReportTask' {
        BeforeEach {
            $script:session = [pscustomobject]@{ hostname = 'array01' }

            Mock Invoke-DeviceManager {
                if ($Resource -match 'range=\[0-') {
                    return [pscustomobject]@{
                        data = @(
                            [pscustomobject]@{ id = '1'; name = 'lun-history'; content = @() }
                            [pscustomobject]@{ id = '2'; name = 'controller-daily'; content = @() }
                        )
                    }
                }
                return [pscustomobject]@{ data = @() }
            }
        }

        It 'GETs pms/report_task and returns every task as OceanstorPerformanceReportTask objects' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0] | Should -BeOfType [OceanstorPerformanceReportTask]
            $result.Name | Should -Contain 'lun-history'

            Should -Invoke Invoke-DeviceManager -ParameterFilter {
                $Method -eq 'GET' -and $Resource -like 'pms/report_task*' -and $ApiV2 -eq $true
            }
        }

        It 'filters client-side by exact Id' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session -Id '2')

            $result.Count | Should -Be 1
            $result[0].Name | Should -Be 'controller-daily'
        }

        It 'filters client-side by Name with wildcard support' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session -Name 'lun*')

            $result.Count | Should -Be 1
            $result[0].Id | Should -Be '1'
        }

        It 'returns every task when Name/Id are omitted' {
            $result = @(Get-DMPerformanceReportTask -WebSession $script:session)

            $result.Count | Should -Be 2
        }
    }
}
