BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
}

Describe 'Get-DMApiErrorMessage' {
    It 'builds the plain message for an unknown code' {
        $message = Get-DMApiErrorMessage -Code -1 -Description 'Share exists'

        $message | Should -Be 'OceanStor API error -1: Share exists'
    }

    It 'appends the session-expiry hint for the known session-expired code' {
        $message = Get-DMApiErrorMessage -Code 1077939726 -Description 'session expired'

        $message | Should -Match '^OceanStor API error 1077939726: session expired\.'
        $message | Should -Match 'call Connect-deviceManager again'
    }

    It 'does not append a hint for a code not in the known table' {
        $message = Get-DMApiErrorMessage -Code 999999 -Description 'some other failure'

        $message | Should -Be 'OceanStor API error 999999: some other failure'
        $message | Should -Not -Match 'Connect-deviceManager'
    }

    It 'inserts the resource context between the code and the description when supplied' {
        $message = Get-DMApiErrorMessage -Code 5 -Description 'not found' -ResourceContext 'lun?range=[0,99]'

        $message | Should -Be "OceanStor API error 5 for resource 'lun?range=[0,99]': not found"
    }

    It 'includes both the resource context and the session-expiry hint together' {
        $message = Get-DMApiErrorMessage -Code 1077939726 -Description 'session expired' -ResourceContext 'host'

        $message | Should -Be "OceanStor API error 1077939726 for resource 'host': session expired. Your OceanStor session may have expired or been invalidated -- call Connect-deviceManager again."
    }

    It 'tolerates an empty description' {
        $message = Get-DMApiErrorMessage -Code 1 -Description ''

        $message | Should -Be 'OceanStor API error 1: '
    }
}
