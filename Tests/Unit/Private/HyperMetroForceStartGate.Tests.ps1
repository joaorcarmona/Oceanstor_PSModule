BeforeAll {
    $script:repoRoot = Resolve-Path "$PSScriptRoot\..\..\..\"
    $script:config = Import-PowerShellDataFile (Join-Path $script:repoRoot 'Tests\Integration\IntegrityValidationConfig.psd1')
    $script:hyperMetroWorkflow = Get-Content -Raw (Join-Path $script:repoRoot 'Tests\Integration\Private\Workflows\HyperMetro.ps1')
}

Describe 'HyperMetro force-start gate' {
    It 'defaults HyperMetro.AllowForceStart to off' {
        $script:config.HyperMetro.ContainsKey('AllowForceStart') | Should -BeTrue
        $script:config.HyperMetro.AllowForceStart | Should -BeFalse
    }

    It 'is independent of the priority-switch and DR-mutation gates' {
        # Force-start must not be enabled implicitly by other DR gates.
        $script:config.HyperMetro.AllowPrioritySwitch | Should -BeFalse
        $script:config.HyperMetro.AllowDrMutation | Should -BeFalse
    }

    It 'gates the workflow force-start step behind AllowForceStart' {
        $script:hyperMetroWorkflow | Should -Match 'if \(\$configuration\.HyperMetro\.AllowForceStart\)'
    }

    It 'marks the force-start step SkippedUnsafe when the gate is off' {
        # The Start-DMHyperMetroPair invocation and its SkippedUnsafe fallback must
        # both reference force-start so a gate-off run reports the step, never runs it.
        $script:hyperMetroWorkflow | Should -Match "Add-SkippedResult -Name 'Start-DMHyperMetroPair' -Status 'SkippedUnsafe'"
        $script:hyperMetroWorkflow | Should -Match 'AllowForceStart = \$true'
    }
}
