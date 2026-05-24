Describe 'test-ModuleRequirements.ps1' {
    BeforeAll {
        $script:requirementsPath = Join-Path $PSScriptRoot '..\..\..\POSH-Oceanstor\Private\test-ModuleRequirements.ps1'
        $script:pwshPath = (Get-Process -Id $PID).Path
    }

    It 'continues without output when ImportExcel is available' {
        $command = "function Get-Module { [pscustomobject]@{ Name = 'ImportExcel' } }; . '$script:requirementsPath'; 'completed'"

        $output = & $script:pwshPath -NoProfile -Command $command

        $LASTEXITCODE | Should -Be 0
        $output | Should -Contain 'completed'
        $output | Should -Not -Contain 'ImportExcel Module is not available or is not installed!'
    }

    It 'prints installation guidance when ImportExcel is unavailable' {
        $command = "function Get-Module { `$null }; . '$script:requirementsPath'; 'unreachable'"

        $output = & $script:pwshPath -NoProfile -Command $command

        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'ImportExcel Module is not available or is not installed!'
        ($output -join "`n") | Should -Match 'Install-Module -Name ImportExcel'
    }
}
