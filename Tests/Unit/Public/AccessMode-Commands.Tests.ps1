BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"

    $script:testModule = New-Module -Name AccessModeCommandsTestModule -ArgumentList $script:repoRoot -ScriptBlock {
        param($root)

        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureConfigPath.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModePolicy.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModeState.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Set-DMAccessModeConfig.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Public\Get-DMAccessMode.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Public\Set-DMAccessMode.ps1')

        Export-ModuleMember -Function Get-DMFeatureConfigPath, Get-DMAccessModePolicy,
            Get-DMAccessModeState, Set-DMAccessModeConfig, Get-DMAccessMode, Set-DMAccessMode
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name AccessModeCommandsTestModule -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
}

Describe 'Access mode control cmdlets' {
    BeforeEach {
        $script:configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dmmode_$([guid]::NewGuid().ToString('n')).json")
        $env:POSH_OCEANSTOR_CONFIG_PATH = $script:configPath
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:configPath) {
            Remove-Item -LiteralPath $script:configPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Get-DMAccessMode with no config file' {
        It 'reports ReadWrite with Source = Default' {
            $mode = Get-DMAccessMode
            $mode.Mode | Should -Be 'ReadWrite'
            $mode.Source | Should -Be 'Default'
        }

        It 'exposes the read-only policy' {
            $mode = Get-DMAccessMode
            $mode.ReadOnlyVerbs | Should -Contain 'Get'
            $mode.ExemptCommands | Should -Contain 'Set-DMAccessMode'
        }

        It 'never creates the config file just by reading' {
            Get-DMAccessMode | Out-Null
            Test-Path -LiteralPath $script:configPath | Should -BeFalse
        }
    }

    Context 'Set-DMAccessMode' {
        It 'writes the Mode override for ReadOnly and reports UserConfig' {
            Set-DMAccessMode -Mode ReadOnly -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            Test-Path -LiteralPath $script:configPath | Should -BeTrue
            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.Mode | Should -Be 'ReadOnly'
            (Get-DMAccessMode).Source | Should -Be 'UserConfig'
        }

        It 'removes the override when set back to ReadWrite' {
            Set-DMAccessMode -Mode ReadOnly -Confirm:$false -WarningAction SilentlyContinue | Out-Null
            Set-DMAccessMode -Mode ReadWrite -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Not -Contain 'Mode'
            (Get-DMAccessMode).Mode | Should -Be 'ReadWrite'
        }

        It 'does not write under -WhatIf' {
            Set-DMAccessMode -Mode ReadOnly -WhatIf -WarningAction SilentlyContinue | Out-Null
            Test-Path -LiteralPath $script:configPath | Should -BeFalse
        }

        It 'rejects an invalid mode via ValidateSet' {
            { Set-DMAccessMode -Mode 'Sideways' -Confirm:$false } | Should -Throw
        }

        It 'preserves an existing feature override when switching mode' {
            Set-Content -LiteralPath $script:configPath -Value '{ "HyperMetro": true }' -Encoding utf8
            Set-DMAccessMode -Mode ReadOnly -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.HyperMetro | Should -BeTrue
            $json.Mode | Should -Be 'ReadOnly'
        }
    }
}
