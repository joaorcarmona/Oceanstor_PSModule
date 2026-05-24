BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\write-DMError.ps1"
}

Describe 'write-DMError' {
    It 'writes the session error details to the host output stream' {
        $sessionError = [pscustomobject]@{
            code        = 1077948993
            description = 'Authentication failed'
            suggestion  = 'Check credentials'
        }

        $output = & { write-DMError -SessionError $sessionError } 6>&1
        $messages = @($output | ForEach-Object { $_.ToString() })

        $messages | Should -Contain 'Error Code:  1077948993'
        $messages | Should -Contain 'Error Description:  Authentication failed'
        $messages | Should -Contain 'Suggestion:  Check credentials'
    }

    It 'accepts a session error from the pipeline' {
        $sessionError = [pscustomobject]@{
            code        = 1
            description = 'Failed'
            suggestion  = 'Retry'
        }

        $output = & { $sessionError | write-DMError } 6>&1

        @($output | ForEach-Object { $_.ToString() }) | Should -Contain 'Error Code:  1'
    }
}
