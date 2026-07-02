BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\Get-DMFilterableProperty.ps1"
}

Describe 'Get-DMFilterableProperty' {
    It 'returns real, visible properties including ones with spaces in their names' {
        $result = Get-DMFilterableProperty -Type ([OceanStorHost])

        $result | Should -Contain 'Name'
        $result | Should -Contain 'Health Status'
        $result | Should -Contain 'Parent Name'
    }

    It 'excludes hidden class-internal properties' {
        $result = Get-DMFilterableProperty -Type ([OceanStorHost])

        $result | Should -Not -Contain 'Session'
        $result | Should -Not -Contain 'WebSession'
    }
}
