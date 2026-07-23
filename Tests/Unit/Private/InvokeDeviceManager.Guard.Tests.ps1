# Exercises the runtime ReadOnly guardrail through the real Invoke-DeviceManager choke point:
# fake public-style *-DM* cmdlets route through it exactly as production cmdlets do, so the
# call-stack verb resolution + live-config enforcement are validated end to end. The guard runs
# BEFORE the session check, so an allowed call fails later at the "no session" throw (proof the
# guardrail let it past) while a blocked call fails at the guardrail itself.

BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"

    $script:testModule = New-Module -Name InvokeDMGuardTestModule -ArgumentList $script:repoRoot -ScriptBlock {
        param($root)

        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMFeatureConfigPath.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModePolicy.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Get-DMAccessModeState.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Assert-DMWriteAllowed.ps1')
        . (Join-Path $root 'POSH-Oceanstor\Private\Invoke-DeviceManager.ps1')

        # Fake public-style cmdlets that route through the real choke point. Named with real verbs so
        # the call-stack resolution keys off them exactly as it would for New-DMLun / Get-DMhost / etc.
        function New-DMFakeThing { Invoke-DeviceManager -Method POST -Resource 'lun' -BodyData @{ x = 1 } }
        function Get-DMFakeThing { Invoke-DeviceManager -Method GET  -Resource 'lun' }
        function Get-DMFakeInner { Invoke-DeviceManager -Method GET  -Resource 'lun' }
        function Set-DMFakeWrap  { Get-DMFakeInner }   # a mutation cmdlet whose internal step is a read

        # Assert-DMWriteAllowed is intentionally NOT exported -- proving the guard finds the private
        # helper from module scope, exactly as the real module does.
        Export-ModuleMember -Function New-DMFakeThing, Get-DMFakeThing, Get-DMFakeInner, Set-DMFakeWrap
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name InvokeDMGuardTestModule -Force -ErrorAction SilentlyContinue
    Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
}

Describe 'Invoke-DeviceManager runtime ReadOnly guardrail' {
    BeforeEach {
        $script:configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dmigd_$([guid]::NewGuid().ToString('n')).json")
        $env:POSH_OCEANSTOR_CONFIG_PATH = $script:configPath
    }

    AfterEach {
        Remove-Item -LiteralPath $script:configPath -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
    }

    Context 'ReadWrite (default: no config file)' {
        It 'lets a mutation past the guard (fails later at the session check, not the guardrail)' {
            { New-DMFakeThing } | Should -Throw -ExpectedMessage '*session*'
        }
    }

    Context 'ReadOnly (live config, no re-import)' {
        BeforeEach {
            Set-Content -LiteralPath $script:configPath -Value '{ "Mode": "ReadOnly" }' -Encoding utf8
        }

        It 'blocks a mutation before any REST work, naming the originating cmdlet' {
            { New-DMFakeThing } | Should -Throw -ExpectedMessage '*ReadOnly*New-DMFakeThing*'
        }

        It 'still allows a read (fails later at the session check, not the guardrail)' {
            { Get-DMFakeThing } | Should -Throw -ExpectedMessage '*session*'
        }

        It 'blocks a mutation even on its internal read step (outermost frame decides)' {
            { Set-DMFakeWrap } | Should -Throw -ExpectedMessage '*ReadOnly*Set-DMFakeWrap*'
        }
    }
}
