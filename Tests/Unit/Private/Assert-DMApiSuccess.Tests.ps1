BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
}

Describe 'Assert-DMApiSuccess' {
    It 'passes the response through unchanged when error.Code is 0' {
        $response = [pscustomobject]@{
            error = [pscustomobject]@{ Code = 0; description = '' }
            data  = [pscustomobject]@{ ID = 'lun-01' }
        }

        $result = Assert-DMApiSuccess -Response $response

        $result | Should -Be $response
        $result.data.ID | Should -Be 'lun-01'
    }

    It 'passes a response through unchanged when it has no error property at all' {
        $response = [pscustomobject]@{ data = 'anything' }

        $result = Assert-DMApiSuccess -Response $response

        $result | Should -Be $response
    }

    It 'returns $null when given $null' {
        $result = Assert-DMApiSuccess -Response $null

        $result | Should -BeNullOrEmpty
    }

    It 'accepts the response from the pipeline' {
        $response = [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }

        $result = $response | Assert-DMApiSuccess

        $result | Should -Be $response
    }

    It 'throws a terminating error with a descriptive message when error.Code is non-zero' {
        $response = [pscustomobject]@{
            error = [pscustomobject]@{ Code = 1077948996; description = 'request rejected' }
        }

        { Assert-DMApiSuccess -Response $response } | Should -Throw '*1077948996*request rejected*'
    }

    It 'throws with ErrorCategory InvalidOperation and a stable FullyQualifiedErrorId' {
        $response = [pscustomobject]@{
            error = [pscustomobject]@{ Code = 1; description = 'duplicate name' }
        }

        try {
            Assert-DMApiSuccess -Response $response
            throw 'Assert-DMApiSuccess did not throw.'
        }
        catch {
            $_.CategoryInfo.Category | Should -Be 'InvalidOperation'
            $_.FullyQualifiedErrorId | Should -Match '^OceanStorApiError'
        }
    }

    It 'matches the message format used by Select-DMResponseData for consistency' {
        # Same "OceanStor API error <Code>: <description>" shape as the Get-DM* error path,
        # so callers see one consistent message regardless of which command failed.
        $response = [pscustomobject]@{
            error = [pscustomobject]@{ Code = 5; description = 'not found' }
        }

        { Assert-DMApiSuccess -Response $response } | Should -Throw '*OceanStor API error 5: not found*'
    }

    It 'includes the session-expiry hint for a mutation command hitting the known code' {
        $response = [pscustomobject]@{
            error = [pscustomobject]@{ Code = 1077939726; description = 'session expired' }
        }

        { Assert-DMApiSuccess -Response $response } |
            Should -Throw '*1077939726*session expired*call Connect-deviceManager again*'
    }
}
