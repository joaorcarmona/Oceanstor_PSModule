BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Get-DMFilterableProperty.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMValidFilterProperty.ps1"
}

Describe 'Assert-DMValidFilterProperty' {
    It 'does not throw for a real, visible property' {
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'Name' } | Should -Not -Throw
    }

    It 'does not throw for a real property with a space in its name' {
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'Health Status' } | Should -Not -Throw
    }

    It 'is case-insensitive, matching PowerShell property lookup semantics' {
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'name' } | Should -Not -Throw
    }

    It 'throws a descriptive error for a property that does not exist' {
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'Bogus' } |
            Should -Throw "*Invalid Filter 'Bogus'*"
    }

    It 'lists valid property names in the error message' {
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'Bogus' } |
            Should -Throw '*Name*Health Status*Parent Name*'
    }

    It 'rejects hidden class-internal properties, since they are not real REST filter fields' {
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'Session' } |
            Should -Throw "*Invalid Filter 'Session'*"
        { Assert-DMValidFilterProperty -Type ([OceanStorHost]) -Filter 'WebSession' } |
            Should -Throw "*Invalid Filter 'WebSession'*"
    }
}
