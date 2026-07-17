# Real Import-Module round-trips are run in a child `pwsh -NoProfile` process so the feature
# filtering is exercised exactly as an end user would hit it, and so repeated -Force imports
# with different configs never contaminate the Pester session's own module/class scope.

BeforeAll {
    $script:repoRoot   = (Resolve-Path "$PSScriptRoot\..\..").Path
    $script:manifest   = Join-Path $script:repoRoot 'POSH-Oceanstor\POSH-Oceanstor.psd1'

    function Invoke-FeatureImport {
        param(
            [string]$ConfigContent  # $null => no config file at all
        )

        $configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dmimport_$([guid]::NewGuid().ToString('n')).json")
        if ($null -ne $ConfigContent) {
            Set-Content -LiteralPath $configPath -Value $ConfigContent -Encoding utf8
        }

        # Child script emits a JSON object describing the exported surface.
        $childScript = @'
$ErrorActionPreference = 'Stop'
Import-Module $env:DMIMPORT_MANIFEST -Force
$functions = @(Get-Command -Module POSH-Oceanstor -CommandType Function | ForEach-Object Name)
$aliases   = @(Get-Command -Module POSH-Oceanstor -CommandType Alias)
$aliasInfo = $aliases | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Target = $_.Definition } }
[pscustomobject]@{
    Functions   = $functions
    AliasNames  = @($aliases | ForEach-Object Name)
    AliasTargets = @($aliasInfo | ForEach-Object Target)
} | ConvertTo-Json -Depth 4 -Compress
'@

        $env:DMIMPORT_MANIFEST = $script:manifest
        if ($null -ne $ConfigContent) {
            $env:POSH_OCEANSTOR_CONFIG_PATH = $configPath
        }
        else {
            Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
        }

        try {
            $json = & pwsh -NoProfile -NonInteractive -Command $childScript
            return ($json | ConvertFrom-Json)
        }
        finally {
            Remove-Item Env:\DMIMPORT_MANIFEST -ErrorAction SilentlyContinue
            Remove-Item Env:\POSH_OCEANSTOR_CONFIG_PATH -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $configPath) {
                Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Module import with default (no) config' {
    BeforeAll {
        $script:default = Invoke-FeatureImport -ConfigContent $null
    }

    It 'hides default-disabled HyperMetro commands' {
        $script:default.Functions | Should -Not -Contain 'Get-DMHyperMetroPair'
        $script:default.Functions | Should -Not -Contain 'New-DMHyperMetroDomain'
    }

    It 'hides default-disabled Replication commands' {
        $script:default.Functions | Should -Not -Contain 'Get-DMReplicationPair'
        $script:default.Functions | Should -Not -Contain 'Get-DMVStorePair'
    }

    It 'exposes enabled commands and the feature-control cmdlets' {
        $script:default.Functions | Should -Contain 'Get-DMhost'
        $script:default.Functions | Should -Contain 'Get-DMFeature'
        $script:default.Functions | Should -Contain 'Enable-DMFeature'
        $script:default.Functions | Should -Contain 'Disable-DMFeature'
    }

    It 'exports the alias of an enabled command' {
        $script:default.AliasNames | Should -Contain 'Get-DMhosts'
    }

    It 'exports no dangling alias (every alias targets an exported function)' {
        $dangling = $script:default.AliasTargets | Where-Object { $_ -notin $script:default.Functions }
        $dangling | Should -BeNullOrEmpty -Because "these exported aliases point at non-exported commands: $($dangling -join ', ')"
    }
}

Describe 'Module import with HyperMetro enabled' {
    BeforeAll {
        $script:enabled = Invoke-FeatureImport -ConfigContent '{ "HyperMetro": true }'
    }

    It 'exposes HyperMetro commands' {
        $script:enabled.Functions | Should -Contain 'Get-DMHyperMetroPair'
        $script:enabled.Functions | Should -Contain 'New-DMHyperMetroDomain'
    }

    It 'still hides Replication commands' {
        $script:enabled.Functions | Should -Not -Contain 'Get-DMReplicationPair'
    }

    It 'keeps every alias resolvable' {
        $dangling = $script:enabled.AliasTargets | Where-Object { $_ -notin $script:enabled.Functions }
        $dangling | Should -BeNullOrEmpty
    }
}
