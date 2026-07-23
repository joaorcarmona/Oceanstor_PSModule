BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"

    $script:testModule = New-Module -Name AccessModeTestModule -ArgumentList $script:repoRoot -ScriptBlock {
        param($root)

        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureConfigPath.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureState.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Set-DMFeatureConfig.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModePolicy.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModeState.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Set-DMAccessModeConfig.ps1')

        Export-ModuleMember -Function Get-DMFeatureConfigPath, Get-DMFeatureState, Set-DMFeatureConfig,
            Get-DMAccessModePolicy, Get-DMAccessModeState, Set-DMAccessModeConfig
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name AccessModeTestModule -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
}

Describe 'Get-DMAccessModePolicy' {
    It 'lists exactly the four non-mutating verbs' {
        (Get-DMAccessModePolicy).ReadOnlyVerbs | Should -Be @('Get', 'Connect', 'Disconnect', 'Export')
    }

    It 'exempts the access-mode control cmdlets so the switch cannot lock itself out' {
        $exempt = (Get-DMAccessModePolicy).ExemptCommands
        $exempt | Should -Contain 'Set-DMAccessMode'
        $exempt | Should -Contain 'Get-DMAccessMode'
    }

    It 'exempts the local-config feature and trace control cmdlets' {
        $exempt = (Get-DMAccessModePolicy).ExemptCommands
        foreach ($cmd in 'Enable-DMFeature', 'Disable-DMFeature', 'Enable-DMRequestTrace',
            'Disable-DMRequestTrace', 'Clear-DMRequestTrace') {
            $exempt | Should -Contain $cmd
        }
    }
}

Describe 'Access mode resolution and persistence' {
    BeforeEach {
        $script:configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dmmode_$([guid]::NewGuid().ToString('n')).json")
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:configPath) {
            Remove-Item -LiteralPath $script:configPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Get-DMAccessModeState' {
        It 'defaults to ReadWrite when no config file exists' {
            Get-DMAccessModeState -ConfigPath $script:configPath | Should -Be 'ReadWrite'
        }

        It 'reads ReadOnly from config' {
            Set-Content -LiteralPath $script:configPath -Value '{ "Mode": "ReadOnly" }' -Encoding utf8
            Get-DMAccessModeState -ConfigPath $script:configPath | Should -Be 'ReadOnly'
        }

        It 'is case-insensitive on the stored value' {
            Set-Content -LiteralPath $script:configPath -Value '{ "Mode": "readonly" }' -Encoding utf8
            Get-DMAccessModeState -ConfigPath $script:configPath | Should -Be 'ReadOnly'
        }

        It 'falls back to ReadWrite on malformed JSON, with a warning' {
            Set-Content -LiteralPath $script:configPath -Value '{ not valid json ' -Encoding utf8
            $warnings = @()
            $mode = Get-DMAccessModeState -ConfigPath $script:configPath -WarningVariable warnings -WarningAction SilentlyContinue
            $mode | Should -Be 'ReadWrite'
            $warnings.Count | Should -BeGreaterThan 0
        }

        It 'falls back to ReadWrite on an unrecognized Mode value, with a warning' {
            Set-Content -LiteralPath $script:configPath -Value '{ "Mode": "Banana" }' -Encoding utf8
            $warnings = @()
            $mode = Get-DMAccessModeState -ConfigPath $script:configPath -WarningVariable warnings -WarningAction SilentlyContinue
            $mode | Should -Be 'ReadWrite'
            $warnings -join ' ' | Should -Match 'Banana'
        }

        It 'never creates the config file just by reading' {
            Get-DMAccessModeState -ConfigPath $script:configPath | Out-Null
            Test-Path -LiteralPath $script:configPath | Should -BeFalse
        }
    }

    Context 'Set-DMAccessModeConfig' {
        It 'writes the Mode key for ReadOnly' {
            Set-DMAccessModeConfig -Mode ReadOnly -ConfigPath $script:configPath | Out-Null
            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.Mode | Should -Be 'ReadOnly'
        }

        It 'removes the Mode key for ReadWrite (default is never stored)' {
            Set-DMAccessModeConfig -Mode ReadOnly -ConfigPath $script:configPath | Out-Null
            Set-DMAccessModeConfig -Mode ReadWrite -ConfigPath $script:configPath | Out-Null
            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Not -Contain 'Mode'
        }

        It 'preserves existing feature overrides when writing the mode' {
            Set-Content -LiteralPath $script:configPath -Value '{ "HyperMetro": true }' -Encoding utf8
            Set-DMAccessModeConfig -Mode ReadOnly -ConfigPath $script:configPath | Out-Null
            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.HyperMetro | Should -BeTrue
            $json.Mode | Should -Be 'ReadOnly'
        }
    }

    Context 'Reserved key does not leak into the feature subsystem' {
        It 'Set-DMFeatureConfig preserves an existing Mode key when toggling a feature' {
            Set-Content -LiteralPath $script:configPath -Value '{ "Mode": "ReadOnly" }' -Encoding utf8
            Set-DMFeatureConfig -Change @{ HyperMetro = $true } -ConfigPath $script:configPath | Out-Null
            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.Mode | Should -Be 'ReadOnly'
            $json.HyperMetro | Should -BeTrue
        }

        It 'Get-DMFeatureState does not warn about Mode and emits no feature named Mode' {
            Set-Content -LiteralPath $script:configPath -Value '{ "Mode": "ReadOnly" }' -Encoding utf8
            $warnings = @()
            $features = Get-DMFeatureState -ConfigPath $script:configPath -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings -join ' ' | Should -Not -Match 'Mode'
            $features.Name | Should -Not -Contain 'Mode'
        }
    }
}
