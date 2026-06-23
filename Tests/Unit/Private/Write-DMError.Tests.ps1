BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Write-DMError.ps1"
}

Describe 'Write-DMError' {
    It 'writes the session error details as warnings' {
        $sessionError = [pscustomobject]@{
            code        = 1077948993
            description = 'Authentication failed'
            suggestion  = 'Check credentials'
        }

        $output = & { Write-DMError -SessionError $sessionError } 3>&1
        $messages = @($output | ForEach-Object { $_.ToString() })

        $messages | Should -Contain 'Error Code: 1077948993'
        $messages | Should -Contain 'Error Description: Authentication failed'
        $messages | Should -Contain 'Suggestion: Check credentials'
    }

    It 'accepts a session error from the pipeline' {
        $sessionError = [pscustomobject]@{
            code        = 1
            description = 'Failed'
            suggestion  = 'Retry'
        }

        $output = & { $sessionError | Write-DMError } 3>&1

        @($output | ForEach-Object { $_.ToString() }) | Should -Contain 'Error Code: 1'
    }
}
