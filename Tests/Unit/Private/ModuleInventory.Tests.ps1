BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"
    $script:manifest = Import-PowerShellDataFile (Join-Path $script:repoRoot 'POSH-Oceanstor\POSH-Oceanstor.psd1')
    $script:coverage = Import-PowerShellDataFile (Join-Path $script:repoRoot 'Tests\ModuleCoverage.psd1')
}

Describe 'Command inventory' {
    It 'every Public command file is declared in FunctionsToExport' {
        $commandFiles = Get-ChildItem (Join-Path $script:repoRoot 'POSH-Oceanstor\Public') -Filter '*.ps1' |
            ForEach-Object { $_.BaseName }

        $undeclared = $commandFiles | Where-Object { $_ -notin $script:manifest.FunctionsToExport }

        $undeclared | Should -BeNullOrEmpty -Because (
            "these Public command files are missing from FunctionsToExport in POSH-Oceanstor.psd1: $($undeclared -join ', ')"
        )
    }

    It 'every FunctionsToExport entry has a matching Public command file' {
        $commandFiles = Get-ChildItem (Join-Path $script:repoRoot 'POSH-Oceanstor\Public') -Filter '*.ps1' |
            ForEach-Object { $_.BaseName }

        $stale = $script:manifest.FunctionsToExport | Where-Object { $_ -notin $commandFiles }

        $stale | Should -BeNullOrEmpty -Because (
            "these FunctionsToExport entries have no matching .ps1 file in Public/: $($stale -join ', ')"
        )
    }
}

Describe 'Class inventory' {
    It 'every class file is declared in Tests/ModuleCoverage.psd1' {
        $classFiles = Get-ChildItem (Join-Path $script:repoRoot 'POSH-Oceanstor\Private') -Filter 'class-*.ps1' |
            ForEach-Object { $_.BaseName -replace '^class-', '' }

        $undeclared = $classFiles | Where-Object { $_ -notin $script:coverage.Classes }

        $undeclared | Should -BeNullOrEmpty -Because (
            "these class files are missing from the Classes array in Tests/ModuleCoverage.psd1: $($undeclared -join ', ')"
        )
    }

    It 'every ModuleCoverage.psd1 Classes entry has a matching class file' {
        $classFiles = Get-ChildItem (Join-Path $script:repoRoot 'POSH-Oceanstor\Private') -Filter 'class-*.ps1' |
            ForEach-Object { $_.BaseName -replace '^class-', '' }

        $stale = $script:coverage.Classes | Where-Object { $_ -notin $classFiles }

        $stale | Should -BeNullOrEmpty -Because (
            "these ModuleCoverage.psd1 Classes entries have no matching class-*.ps1 file: $($stale -join ', ')"
        )
    }
}
