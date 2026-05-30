BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Validate-Ipv4Address.ps1"
}

Describe 'Test-IPv4Address' {
    It 'returns true for a valid IPv4 address' {
        Test-IPv4Address -IPv4 '192.168.10.25' | Should -BeTrue
    }

    It 'returns false for an address with an octet greater than 255' {
        Test-IPv4Address -IPv4 '192.168.10.256' | Should -BeFalse
    }

    It 'accepts IPv4 input from the pipeline' {
        '10.0.0.1' | Test-IPv4Address | Should -BeTrue
    }
}
