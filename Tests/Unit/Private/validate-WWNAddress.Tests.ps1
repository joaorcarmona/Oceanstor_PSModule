BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\validate-WWNAddress.ps1"
}

Describe 'validate-WWNAddress' {
    It 'accepts a valid Fibre Channel WWN' {
        validate-WWNAddress -WWN '10000090FA123456' | Should -BeTrue
    }

    It 'rejects invalid or prohibited WWNs' -TestCases @(
        @{ WWN = '10000090FA12345' }
        @{ WWN = '10000090FA12345G' }
        @{ WWN = '0000000000000000' }
        @{ WWN = 'FFFFFFFFFFFFFFFF' }
    ) {
        param($WWN)
        validate-WWNAddress -WWN $WWN | Should -BeFalse
    }
}
