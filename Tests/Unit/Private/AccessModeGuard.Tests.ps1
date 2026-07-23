BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"

    $script:testModule = New-Module -Name AccessModeGuardTestModule -ArgumentList $script:repoRoot -ScriptBlock {
        param($root)

        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureConfigPath.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModePolicy.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModeState.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Assert-DMWriteAllowed.ps1')

        Export-ModuleMember -Function Get-DMFeatureConfigPath, Get-DMAccessModePolicy,
            Get-DMAccessModeState, Assert-DMWriteAllowed
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name AccessModeGuardTestModule -Force -ErrorAction SilentlyContinue
}

Describe 'Assert-DMWriteAllowed (runtime ReadOnly decision)' {
    BeforeEach {
        $script:roConfig = Join-Path ([System.IO.Path]::GetTempPath()) ("dmguard_ro_$([guid]::NewGuid().ToString('n')).json")
        Set-Content -LiteralPath $script:roConfig -Value '{ "Mode": "ReadOnly" }' -Encoding utf8

        # No file on disk => ReadWrite default (Get-DMAccessModeState fails open).
        $script:rwConfig = Join-Path ([System.IO.Path]::GetTempPath()) ("dmguard_rw_$([guid]::NewGuid().ToString('n')).json")
    }

    AfterEach {
        Remove-Item -LiteralPath $script:roConfig -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $script:rwConfig -Force -ErrorAction SilentlyContinue
    }

    Context 'ReadWrite (default) mode' {
        It 'allows a mutation command' {
            { Assert-DMWriteAllowed -Method POST -Command 'New-DMLun' -ConfigPath $script:rwConfig } | Should -Not -Throw
        }

        It 'allows an unknown-caller write' {
            { Assert-DMWriteAllowed -Method DELETE -Command '' -ConfigPath $script:rwConfig } | Should -Not -Throw
        }
    }

    Context 'ReadOnly mode' {
        It 'blocks a mutation command with a helpful, greppable error naming the cmdlet' {
            { Assert-DMWriteAllowed -Method POST -Command 'New-DMLun' -ConfigPath $script:roConfig } |
                Should -Throw -ExpectedMessage '*ReadOnly*New-DMLun*'
        }

        It 'blocks Set / Remove / Add mutations regardless of HTTP method' {
            foreach ($c in @(
                    @{ m = 'PUT';    n = 'Set-DMLun' },
                    @{ m = 'DELETE'; n = 'Remove-DMHost' },
                    @{ m = 'POST';   n = 'Add-DMLunToLunGroup' })) {
                { Assert-DMWriteAllowed -Method $c.m -Command $c.n -ConfigPath $script:roConfig } | Should -Throw
            }
        }

        It 'allows read verbs (Get) even when the HTTP method is a write (query-by-POST)' {
            { Assert-DMWriteAllowed -Method POST -Command 'Get-DMPerformance' -ConfigPath $script:roConfig } | Should -Not -Throw
        }

        It 'allows session verbs Connect and Disconnect' {
            { Assert-DMWriteAllowed -Method POST   -Command 'Connect-deviceManager'    -ConfigPath $script:roConfig } | Should -Not -Throw
            { Assert-DMWriteAllowed -Method DELETE -Command 'Disconnect-deviceManager' -ConfigPath $script:roConfig } | Should -Not -Throw
        }

        It 'allows exempt local-config controls so the switch cannot self-lock' {
            foreach ($n in @('Set-DMAccessMode', 'Enable-DMFeature', 'Enable-DMRequestTrace', 'Clear-DMRequestTrace')) {
                { Assert-DMWriteAllowed -Method POST -Command $n -ConfigPath $script:roConfig } | Should -Not -Throw
            }
        }

        It 'allows an unknown caller doing a GET (fallback signal)' {
            { Assert-DMWriteAllowed -Method GET -Command '' -ConfigPath $script:roConfig } | Should -Not -Throw
        }

        It 'blocks an unknown caller doing a write (fallback signal)' {
            { Assert-DMWriteAllowed -Method POST -Command '' -ConfigPath $script:roConfig } |
                Should -Throw -ExpectedMessage '*ReadOnly*POST*'
        }
    }
}
