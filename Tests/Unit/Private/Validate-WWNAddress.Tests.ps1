BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Validate-WWNAddress.ps1"
}

Describe 'Validate-WWNAddress' {
    It 'accepts a valid Fibre Channel WWN' {
        Validate-WWNAddress -WWN '10000090FA123456' | Should -BeTrue
    }

    It 'rejects invalid or prohibited WWNs' -TestCases @(
        @{ WWN = '10000090FA12345' }
        @{ WWN = '10000090FA12345G' }
        @{ WWN = '0000000000000000' }
        @{ WWN = 'FFFFFFFFFFFFFFFF' }
    ) {
        param($WWN)
        Validate-WWNAddress -WWN $WWN | Should -BeFalse
    }
}
