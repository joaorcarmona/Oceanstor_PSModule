BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"
    $script:manifest = Import-PowerShellDataFile (Join-Path $script:repoRoot 'POSH-Oceanstor\POSH-Oceanstor.psd1')
    $script:map      = Import-PowerShellDataFile (Join-Path $script:repoRoot 'POSH-Oceanstor\DMFeatureMap.psd1')
    $script:features = $script:map.Features
    $script:allMapped = $script:features.Values.Commands
}

Describe 'Feature map inventory' {
    It 'every FunctionsToExport entry is assigned to a feature' {
        $unmapped = $script:manifest.FunctionsToExport | Where-Object { $_ -notin $script:allMapped }

        $unmapped | Should -BeNullOrEmpty -Because (
            "these exported commands are not assigned to any feature in DMFeatureMap.psd1: $($unmapped -join ', ')"
        )
    }

    It 'every mapped command is a real FunctionsToExport entry' {
        $stale = $script:allMapped | Where-Object { $_ -notin $script:manifest.FunctionsToExport }

        $stale | Should -BeNullOrEmpty -Because (
            "these DMFeatureMap.psd1 commands have no matching FunctionsToExport entry: $($stale -join ', ')"
        )
    }

    It 'no command is assigned to more than one feature' {
        $duplicates = $script:allMapped | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }

        $duplicates | Should -BeNullOrEmpty -Because (
            "these commands appear in more than one feature: $($duplicates -join ', ')"
        )
    }
}

Describe 'Feature map defaults' {
    It 'HyperMetro ships disabled' {
        $script:features.HyperMetro.DefaultEnabled | Should -BeFalse
    }

    It 'Replication ships disabled' {
        $script:features.Replication.DefaultEnabled | Should -BeFalse
    }

    It 'every other feature ships enabled' {
        $unexpectedlyOff = $script:features.GetEnumerator() |
            Where-Object { $_.Key -notin @('HyperMetro', 'Replication') -and -not $_.Value.DefaultEnabled } |
            ForEach-Object { $_.Key }

        $unexpectedlyOff | Should -BeNullOrEmpty -Because (
            "only HyperMetro and Replication may default to disabled; these also do: $($unexpectedlyOff -join ', ')"
        )
    }

    It 'Core is the only locked feature and it is enabled' {
        $locked = $script:features.GetEnumerator() | Where-Object { $_.Value.Locked } | ForEach-Object { $_.Key }
        $locked | Should -Be 'Core'
        $script:features.Core.DefaultEnabled | Should -BeTrue
    }

    It 'the feature-control cmdlets live in Core' {
        foreach ($cmd in 'Get-DMFeature', 'Enable-DMFeature', 'Disable-DMFeature') {
            $script:features.Core.Commands | Should -Contain $cmd
        }
    }

    It 'every feature has a non-empty description' {
        $missing = $script:features.GetEnumerator() |
            Where-Object { [string]::IsNullOrWhiteSpace($_.Value.Description) } |
            ForEach-Object { $_.Key }

        $missing | Should -BeNullOrEmpty -Because "these features have no Description: $($missing -join ', ')"
    }
}
