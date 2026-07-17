BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"

    $script:testModule = New-Module -Name FeatureCommandsTestModule -ArgumentList $script:repoRoot -ScriptBlock {
        param($root)

        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureConfigPath.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureState.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Set-DMFeatureConfig.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Public\Get-DMFeature.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Public\Enable-DMFeature.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Public\Disable-DMFeature.ps1')

        Export-ModuleMember -Function Get-DMFeatureConfigPath, Get-DMFeatureState, Set-DMFeatureConfig,
            Get-DMFeature, Enable-DMFeature, Disable-DMFeature
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name FeatureCommandsTestModule -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
}

Describe 'Feature control cmdlets' {
    BeforeEach {
        $script:configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dmfeat_$([guid]::NewGuid().ToString('n')).json")
        $env:POSH_OCEANSTOR_CONFIG_PATH = $script:configPath
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:configPath) {
            Remove-Item -LiteralPath $script:configPath -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Get-DMFeature with no config file' {
        It 'reports built-in defaults with Source = Default' {
            $features = Get-DMFeature

            ($features | Where-Object Name -eq 'HyperMetro').Enabled | Should -BeFalse
            ($features | Where-Object Name -eq 'Replication').Enabled | Should -BeFalse
            ($features | Where-Object Name -eq 'Host').Enabled | Should -BeTrue
            ($features | Where-Object Name -eq 'HyperMetro').Source | Should -Be 'Default'
        }

        It 'never creates the config file just by reading' {
            Get-DMFeature | Out-Null
            Test-Path -LiteralPath $script:configPath | Should -BeFalse
        }

        It 'errors on an unknown -Name' {
            { Get-DMFeature -Name 'Bogus' -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'Enable-DMFeature' {
        It 'writes only the changed override to JSON' {
            Enable-DMFeature -Name HyperMetro -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            Test-Path -LiteralPath $script:configPath | Should -BeTrue
            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Be 'HyperMetro'
            $json.HyperMetro | Should -BeTrue
            (Get-DMFeature -Name HyperMetro).Source | Should -Be 'UserConfig'
        }

        It 'enabling an already-default-on feature leaves no redundant key' {
            Enable-DMFeature -Name Host -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Not -Contain 'Host'
        }

        It 'does not write under -WhatIf' {
            Enable-DMFeature -Name HyperMetro -WhatIf -WarningAction SilentlyContinue | Out-Null
            Test-Path -LiteralPath $script:configPath | Should -BeFalse
        }

        It 'throws on an unknown feature name' {
            { Enable-DMFeature -Name 'NotAFeature' -Confirm:$false } | Should -Throw
        }
    }

    Context 'Disable-DMFeature' {
        It 'removes the override key when toggled back to default' {
            Enable-DMFeature -Name HyperMetro -Confirm:$false -WarningAction SilentlyContinue | Out-Null
            Disable-DMFeature -Name HyperMetro -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.PSObject.Properties.Name | Should -Not -Contain 'HyperMetro'
        }

        It 'writes a disable override for a default-on feature' {
            Disable-DMFeature -Name Host -Confirm:$false -WarningAction SilentlyContinue | Out-Null

            $json = Get-Content -LiteralPath $script:configPath -Raw | ConvertFrom-Json
            $json.Host | Should -BeFalse
            (Get-DMFeature -Name Host).Enabled | Should -BeFalse
        }

        It 'refuses to disable the locked Core feature' {
            { Disable-DMFeature -Name Core -Confirm:$false } | Should -Throw
        }

        It 'throws on an unknown feature name' {
            { Disable-DMFeature -Name 'NotAFeature' -Confirm:$false } | Should -Throw
        }
    }

    Context 'Malformed config' {
        It 'falls back to defaults and warns' {
            Set-Content -LiteralPath $script:configPath -Value '{ this is not valid json ' -Encoding utf8

            $warnings = @()
            $features = Get-DMFeatureState -WarningVariable warnings -WarningAction SilentlyContinue

            $warnings.Count | Should -BeGreaterThan 0
            ($features | Where-Object Name -eq 'Host').Enabled | Should -BeTrue
            ($features | Where-Object Name -eq 'HyperMetro').Enabled | Should -BeFalse
        }
    }

    Context 'Unknown keys in config' {
        It 'warns about and ignores unmapped feature keys' {
            Set-Content -LiteralPath $script:configPath -Value '{ "Bogus": true }' -Encoding utf8

            $warnings = @()
            $features = Get-DMFeatureState -WarningVariable warnings -WarningAction SilentlyContinue

            $warnings -join ' ' | Should -Match 'Bogus'
            $features.Name | Should -Not -Contain 'Bogus'
        }
    }
}
