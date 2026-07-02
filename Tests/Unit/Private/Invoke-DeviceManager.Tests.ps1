BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DeviceManager.ps1"
}

Describe 'Invoke-DeviceManager' {
    BeforeEach {
        $script:session = [pscustomobject]@{
            Hostname             = 'oceanstor.test'
            DeviceId             = 'device-01'
            Headers              = @{ iBaseToken = 'Test-token' }
            WebSession           = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            SkipCertificateCheck = $false
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
        Remove-Variable -Name CurrentOceanstorSession -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name DeviceManagerTraceAction -Scope Script -ErrorAction SilentlyContinue
        Remove-Variable -Name DeviceManagerTraceContext -Scope Script -ErrorAction SilentlyContinue
    }

    It 'builds the REST request using the supplied session' {
        $result = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'

        $result | Should -Be $script:successResult
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/device-01/lun' -and
            $Headers.iBaseToken -eq 'Test-token' -and
            $WebSession -eq $script:session.WebSession -and
            $ContentType -eq 'application/json' -and
            -not $SkipCertificateCheck -and
            -not $Body
        }
    }

    It 'passes SkipCertificateCheck only when the session opts in' {
        $script:session.SkipCertificateCheck = $true

        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'lun'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $SkipCertificateCheck
        }
    }

    It 'uses the module-scoped CurrentOceanstorSession session when WebSession is omitted' {
        $script:CurrentOceanstorSession = $script:session

        $null = Invoke-DeviceManager -Method GET -Resource 'system/'

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/device-01/system/' -and
            $Headers.iBaseToken -eq 'Test-token' -and
            $WebSession -eq $script:session.WebSession
        }
    }

    It 'serializes BodyData as JSON for a request with a body' {
        $bodyData = @{
            NAME     = 'unit-test-lun'
            CAPACITY = 1024
        }

        $null = Invoke-DeviceManager -WebSession $script:session -Method POST -Resource 'lun' -BodyData $bodyData

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/device-01/lun' -and
            $Body -and
            ($Body | ConvertFrom-Json).NAME -eq 'unit-test-lun' -and
            ($Body | ConvertFrom-Json).CAPACITY -eq 1024
        }
    }

    It 'builds API v2 requests for protection group resources' {
        $null = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'protectgroup' -ApiV2

        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'GET' -and
            $Uri -eq 'https://oceanstor.test:8088/api/v2/protectgroup'
        }
    }

    It 'throws a clear error when no session is available' {
        $script:CurrentOceanstorSession = $null

        { Invoke-DeviceManager -Method GET -Resource 'lun' } | Should -Throw '*Connect-deviceManager*'

        Should -Invoke Invoke-RestMethod -Times 0 -Exactly
    }

    It 'converts a raw string response with case-conflicting JSON keys to a PSCustomObject' {
        Mock Invoke-RestMethod {
            # Simulate PS7 builds that return the raw body string instead of throwing when
            # Invoke-RestMethod encounters duplicate case-insensitive keys.
            '{"data":{"snapType":1,"SNAPTYPE":2,"ID":"snap-01"},"error":{"code":0}}'
        }

        $result = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'fssnapshot/42'

        $result | Should -BeOfType [pscustomobject]
        $result.data.SNAPTYPE | Should -Be 2
        $result.data.ID       | Should -Be 'snap-01'
        $result.error.code    | Should -Be 0
    }

    It 'falls back to Invoke-WebRequest and normalises case-conflicting JSON keys (message path)' {
        Mock Invoke-RestMethod {
            throw [System.ArgumentException]::new(
                "Cannot convert the JSON string because it contains keys with different casing. " +
                "Please use the -AsHashTable switch instead. The key that was attempted to be " +
                "added to the existing key 'snapType' was 'SNAPTYPE'."
            )
        }
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '{"data":[{"snapType":1,"SNAPTYPE":2,"ID":"snap-01"}],"error":{"code":0}}'
            }
        }

        $result = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'fssnapshot'

        $result.data[0].SNAPTYPE | Should -Be 2
        $result.data[0].ID       | Should -Be 'snap-01'
        $result.error.code       | Should -Be 0
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }

    It 'falls back to Invoke-WebRequest when FullyQualifiedErrorId matches WebCmdletCannotConvertContentException' {
        Mock Invoke-RestMethod {
            $ex = [System.Exception]::new('The content could not be converted.')
            $er = [System.Management.Automation.ErrorRecord]::new(
                $ex,
                'WebCmdletCannotConvertContentException,Microsoft.PowerShell.Commands.InvokeRestMethodCommand',
                [System.Management.Automation.ErrorCategory]::InvalidArgument,
                $null
            )
            throw $er
        }
        Mock Invoke-WebRequest {
            [pscustomobject]@{
                Content = '{"data":{"snapType":1,"SNAPTYPE":2,"ID":"snap-02"},"error":{"code":0}}'
            }
        }

        $result = Invoke-DeviceManager -WebSession $script:session -Method GET -Resource 'fssnapshot/42'

        $result.data.SNAPTYPE | Should -Be 2
        $result.data.ID       | Should -Be 'snap-02'
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }

    It 'returns REST error responses so callers can report failures and perform cleanup' {
        $errorResult = [pscustomobject]@{
            error = [pscustomobject]@{ code = 1077948996; description = 'request rejected' }
        }
        Mock Invoke-RestMethod { $errorResult }

        $result = Invoke-DeviceManager -WebSession $script:session -Method POST -Resource 'lun' -BodyData @{ NAME = 'invalid' }

        $result.error.code | Should -Be 1077948996
        $result.error.description | Should -Be 'request rejected'
    }

    It 'emits opt-in REST trace records and redacts sensitive request values' {
        $script:traceRecords = [System.Collections.Generic.List[object]]::new()
        $script:DeviceManagerTraceContext = [pscustomobject]@{ Name = 'New-DMIscsiInitiator'; Category = 'Mutation' }
        $script:DeviceManagerTraceAction = { param($entry) $script:traceRecords.Add($entry) }

        $null = Invoke-DeviceManager -WebSession $script:session -Method POST -Resource 'iscsi_initiator' `
            -BodyData @{ ID = 'iqn.test'; CHAPPASSWORD = 'super-secret' }

        $script:traceRecords.Count | Should -Be 1
        $script:traceRecords[0].Step | Should -Be 'New-DMIscsiInitiator'
        $script:traceRecords[0].Method | Should -Be 'POST'
        $script:traceRecords[0].Resource | Should -Be 'iscsi_initiator'
        $script:traceRecords[0].Request.CHAPPASSWORD | Should -Be '[REDACTED]'
        $script:traceRecords[0].Response.data.ID | Should -Be 'lun-01'
    }
}
