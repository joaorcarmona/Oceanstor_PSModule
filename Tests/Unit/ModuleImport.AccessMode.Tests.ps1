# Real Import-Module round-trips are run in a child `pwsh -NoProfile` process so the ReadOnly
# guardrail is exercised exactly as an end user would hit it, and so repeated -Force imports with
# different configs never contaminate the Pester session's own module/class scope.

BeforeAll {
    $script:repoRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
    $script:manifest = Join-Path $script:repoRoot 'POSH-Oceanstor\POSH-Oceanstor.psd1'

    function Invoke-AccessModeImport {
        param(
            [string]$ConfigContent  # $null => no config file at all
        )

        $configPath = Join-Path ([System.IO.Path]::GetTempPath()) ("dmimport_$([guid]::NewGuid().ToString('n')).json")
        if ($null -ne $ConfigContent) {
            Set-Content -LiteralPath $configPath -Value $ConfigContent -Encoding utf8
        }

        # Child script emits a JSON object describing the exported surface plus the live policy.
        $childScript = @'
$ErrorActionPreference = 'Stop'
Import-Module $env:DMIMPORT_MANIFEST -Force
$functions = @(Get-Command -Module POSH-Oceanstor -CommandType Function | ForEach-Object Name)
$aliases   = @(Get-Command -Module POSH-Oceanstor -CommandType Alias)
$aliasInfo = $aliases | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Target = $_.Definition } }
$mode      = Get-DMAccessMode
[pscustomobject]@{
    Functions      = $functions
    AliasTargets   = @($aliasInfo | ForEach-Object Target)
    ActiveInSession = $mode.ActiveInSession
    ReadOnlyVerbs  = @($mode.ReadOnlyVerbs)
    ExemptCommands = @($mode.ExemptCommands)
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

Describe 'Module import in ReadWrite (default) mode' {
    BeforeAll {
        $script:rw = Invoke-AccessModeImport -ConfigContent $null
    }

    It 'reports the session as ReadWrite' {
        $script:rw.ActiveInSession | Should -Be 'ReadWrite'
    }

    It 'exports mutation commands' {
        $script:rw.Functions | Should -Contain 'New-DMLun'
        $script:rw.Functions | Should -Contain 'Set-DMHost'
    }

    It 'exports the access-mode control cmdlets' {
        $script:rw.Functions | Should -Contain 'Get-DMAccessMode'
        $script:rw.Functions | Should -Contain 'Set-DMAccessMode'
    }
}

Describe 'Module import in ReadOnly mode' {
    BeforeAll {
        $script:ro = Invoke-AccessModeImport -ConfigContent '{ "Mode": "ReadOnly" }'
    }

    It 'reports the session as ReadOnly' {
        $script:ro.ActiveInSession | Should -Be 'ReadOnly'
    }

    It 'hides array-mutating commands' {
        foreach ($cmd in 'New-DMLun', 'Set-DMLun', 'Remove-DMHost', 'Add-DMLunToLunGroup') {
            $script:ro.Functions | Should -Not -Contain $cmd
        }
    }

    It 'keeps inspection, session, and export commands' {
        foreach ($cmd in 'Get-DMhost', 'Get-DMSystem', 'Connect-deviceManager', 'Disconnect-deviceManager', 'Export-DMInventory') {
            $script:ro.Functions | Should -Contain $cmd
        }
    }

    It 'keeps the exempt local-config control cmdlets so the switch is not self-locking' {
        foreach ($cmd in 'Set-DMAccessMode', 'Get-DMAccessMode', 'Enable-DMFeature', 'Enable-DMRequestTrace') {
            $script:ro.Functions | Should -Contain $cmd
        }
    }

    It 'exports nothing outside the allowed verbs or the exempt list' {
        $leak = $script:ro.Functions | Where-Object {
            (($_ -split '-', 2)[0] -notin $script:ro.ReadOnlyVerbs) -and ($_ -notin $script:ro.ExemptCommands)
        }
        $leak | Should -BeNullOrEmpty -Because "these exported commands are neither read-only-verbed nor exempt: $($leak -join ', ')"
    }

    It 'exports no dangling alias (every alias targets an exported function)' {
        $dangling = $script:ro.AliasTargets | Where-Object { $_ -notin $script:ro.Functions }
        $dangling | Should -BeNullOrEmpty -Because "these exported aliases point at non-exported commands: $($dangling -join ', ')"
    }
}

Describe 'Access mode composes with feature gating' {
    BeforeAll {
        $script:combo = Invoke-AccessModeImport -ConfigContent '{ "Mode": "ReadOnly", "HyperMetro": true }'
    }

    It 'exposes the enabled feature''s read-only commands' {
        $script:combo.Functions | Should -Contain 'Get-DMHyperMetroPair'
    }

    It 'still hides the enabled feature''s mutation commands' {
        $script:combo.Functions | Should -Not -Contain 'New-DMHyperMetroDomain'
    }
}
