BeforeDiscovery {
    $script:testModule = New-Module -Name SaveDMDeviceManagerFileTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-WebRequest { param([string]$Method, [string]$Uri, $Headers, $WebSession, [string]$OutFile, [int]$TimeoutSec, [switch]$SkipCertificateCheck) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Save-DMDeviceManagerFile.ps1"

        Export-ModuleMember -Function Save-DMDeviceManagerFile
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name SaveDMDeviceManagerFileTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SaveDMDeviceManagerFileTestModule {
    Describe 'Save-DMDeviceManagerFile' {
        BeforeEach {
            $script:session = [pscustomobject]@{
                hostname             = 'array01'
                DeviceId             = 'device01'
                Headers              = @{ iBaseToken = 'tok' }
                WebSession           = [pscustomobject]@{ fake = $true }
                SkipCertificateCheck = $false
            }
            $script:outPath = Join-Path $TestDrive 'report.zip'

            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value 'binary-content'
            }
        }

        It 'builds the v2 API URI and forwards session headers/webSession' {
            Save-DMDeviceManagerFile -WebSession $script:session -Resource 'pms/report_task/file?log_id=1' -OutFile $script:outPath -ApiV2 | Out-Null

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $Uri -eq 'https://array01:8088/api/v2/pms/report_task/file?log_id=1' -and
                $Headers.iBaseToken -eq 'tok' -and
                $OutFile -eq $script:outPath
            }
        }

        It 'builds the v1 deviceManager URI when -ApiV2 is not specified' {
            Save-DMDeviceManagerFile -WebSession $script:session -Resource 'some/resource' -OutFile $script:outPath | Out-Null

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://array01:8088/deviceManager/rest/device01/some/resource'
            }
        }

        It 'forwards -SkipCertificateCheck when the session requests it' {
            $script:session.SkipCertificateCheck = $true

            Save-DMDeviceManagerFile -WebSession $script:session -Resource 'pms/report_task/file?log_id=1' -OutFile $script:outPath -ApiV2 | Out-Null

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $SkipCertificateCheck -eq $true
            }
        }

        It 'forwards -TimeoutSec only when explicitly bound' {
            Save-DMDeviceManagerFile -WebSession $script:session -Resource 'pms/report_task/file?log_id=1' -OutFile $script:outPath -ApiV2 -TimeoutSec 30 | Out-Null

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $TimeoutSec -eq 30
            }
        }

        It 'falls back to $script:CurrentOceanstorSession when -WebSession is not supplied' {
            $script:CurrentOceanstorSession = $script:session

            Save-DMDeviceManagerFile -Resource 'pms/report_task/file?log_id=1' -OutFile $script:outPath -ApiV2 | Out-Null

            Should -Invoke Invoke-WebRequest -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://array01:8088/api/v2/pms/report_task/file?log_id=1'
            }

            $script:CurrentOceanstorSession = $null
        }

        It 'throws when no session is available' {
            $script:CurrentOceanstorSession = $null

            { Save-DMDeviceManagerFile -Resource 'pms/report_task/file?log_id=1' -OutFile $script:outPath -ApiV2 } | Should -Throw '*no session available*'
        }

        It 'returns a FileInfo for the downloaded file' {
            $result = Save-DMDeviceManagerFile -WebSession $script:session -Resource 'pms/report_task/file?log_id=1' -OutFile $script:outPath -ApiV2

            $result | Should -BeOfType [System.IO.FileInfo]
            $result.FullName | Should -Be (Get-Item -LiteralPath $script:outPath).FullName
        }
    }
}
