BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\invoke-DeviceManager.ps1"
}

Describe 'invoke-DeviceManager' {
    BeforeEach {
        $script:session = [pscustomobject]@{
            Hostname   = 'oceanstor.test'
            DeviceId   = 'device-01'
            Headers    = @{ iBaseToken = 'test-token' }
            WebSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        }

        $script:successResult = [pscustomobject]@{
            error = [pscustomobject]@{ code = 0 }
            data  = [pscustomobject]@{ ID = 'lun-01' }
        }

        Mock Invoke-RestMethod {
            return $script:successResult
        }
    }

    AfterEach {
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
    }

    It 'builds the REST request using the supplied session' {
        $result = invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'

        $result | Should -Be $script:successResult
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/device-01/lun' -and
            $Headers.iBaseToken -eq 'test-token' -and
            $WebSession -eq $script:session.WebSession -and
            $ContentType -eq 'application/json' -and
            $SkipCertificateCheck -and
            -not $Body
        }
    }

    It 'uses the global deviceManager session when WebSession is omitted' {
        $global:deviceManager = $script:session

        $null = invoke-DeviceManager -Method GET -Resource 'system/'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/device-01/system/' -and
            $Headers.iBaseToken -eq 'test-token' -and
            $WebSession -eq $script:session.WebSession
        }
    }

    It 'serializes BodyData as JSON for a request with a body' {
        $bodyData = @{
            NAME     = 'unit-test-lun'
            CAPACITY = 1024
        }

        $null = invoke-DeviceManager -WebSession $script:session -Method POST -Resource 'lun' -BodyData $bodyData

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/device-01/lun' -and
            $Body -and
            ($Body | ConvertFrom-Json).NAME -eq 'unit-test-lun' -and
            ($Body | ConvertFrom-Json).CAPACITY -eq 1024
        }
    }

    It 'builds API v2 requests for protection group resources' {
        $null = invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'protectgroup' -ApiV2

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://oceanstor.test:8088/api/v2/protectgroup'
        }
    }
}
