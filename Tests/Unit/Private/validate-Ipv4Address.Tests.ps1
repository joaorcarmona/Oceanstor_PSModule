BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\validate-Ipv4Address.ps1"
}

Describe 'test-IPv4Address' {
    It 'returns true for a valid IPv4 address' {
        test-IPv4Address -IPv4 '192.168.10.25' | Should -BeTrue
    }

    It 'returns false for an address with an octet greater than 255' {
        test-IPv4Address -IPv4 '192.168.10.256' | Should -BeFalse
    }

    It 'accepts IPv4 input from the pipeline' {
        '10.0.0.1' | test-IPv4Address | Should -BeTrue
    }
}
