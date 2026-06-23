BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Test-WWNAddress.ps1"
}

Describe 'Test-WWNAddress' {
    It 'accepts a valid Fibre Channel WWN' {
        Test-WWNAddress -WWN '10000090FA123456' | Should -BeTrue
    }

    It 'rejects invalid or prohibited WWNs' -TestCases @(
        @{ WWN = '10000090FA12345' }
        @{ WWN = '10000090FA12345G' }
        @{ WWN = '0000000000000000' }
        @{ WWN = 'FFFFFFFFFFFFFFFF' }
    ) {
        param($WWN)
        Test-WWNAddress -WWN $WWN | Should -BeFalse
    }

    It 'resolves the Validate-WWNAddress compatibility alias' {
        Validate-WWNAddress -WWN '10000090FA123456' | Should -BeTrue
    }
}
