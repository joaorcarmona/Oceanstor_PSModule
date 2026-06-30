BeforeAll {
    . "$PSScriptRoot\..\..\Integration\Private\ValidationHelpers.ps1"

    function Set-DMValidationRequestTraceContext {
        param([string]$Name, [string]$Category)
    }
}

Describe 'ValidationHelpers ownership tracking' {
    BeforeEach {
        $script:NoProgress = $true
        $script:ShowTestExecution = $false
        $script:checks = [System.Collections.Generic.List[object]]::new()
        $script:cleanupActions = [System.Collections.Generic.List[object]]::new()
        $script:owned = @{
            Widget = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }
    }

    Context 'Register/Assert/Complete-TestOwnedResource' {
        It 'registers and asserts an owned resource without throwing' {
            Register-TestOwnedResource -Kind Widget -Identity 'widget-1'

            { Assert-TestOwnedResource -Kind Widget -Identity 'widget-1' } | Should -Not -Throw
        }

        It 'throws when asserting an identity that was never registered' {
            { Assert-TestOwnedResource -Kind Widget -Identity 'widget-unknown' } | Should -Throw '*Safety guard*'
        }

        It 'removes ownership on Complete-TestOwnedResource' {
            Register-TestOwnedResource -Kind Widget -Identity 'widget-1'

            Complete-TestOwnedResource -Kind Widget -Identity 'widget-1'

            { Assert-TestOwnedResource -Kind Widget -Identity 'widget-1' } | Should -Throw '*Safety guard*'
        }
    }

    Context 'Update-TestOwnedResourceIdentity' {
        It 'transfers ownership from the old identity to the new identity' {
            Register-TestOwnedResource -Kind Widget -Identity 'widget-1'

            Update-TestOwnedResourceIdentity -Kind Widget -OldIdentity 'widget-1' -NewIdentity 'widget-1-renamed'

            $owned.Widget.Contains('widget-1') | Should -BeFalse
            $owned.Widget.Contains('widget-1-renamed') | Should -BeTrue
        }

        It 'throws and leaves ownership unchanged when the old identity is not owned' {
            { Update-TestOwnedResourceIdentity -Kind Widget -OldIdentity 'widget-missing' -NewIdentity 'widget-new' } |
                Should -Throw '*Safety guard*'

            $owned.Widget.Contains('widget-new') | Should -BeFalse
        }

        It 'throws and leaves ownership unchanged when the new identity is already registered' {
            Register-TestOwnedResource -Kind Widget -Identity 'widget-1'
            Register-TestOwnedResource -Kind Widget -Identity 'widget-2'

            { Update-TestOwnedResourceIdentity -Kind Widget -OldIdentity 'widget-1' -NewIdentity 'widget-2' } |
                Should -Throw '*already registered*'

            $owned.Widget.Contains('widget-1') | Should -BeTrue
            $owned.Widget.Contains('widget-2') | Should -BeTrue
        }
    }

    Context 'Invoke-OwnedRemoval' {
        It 'does not invoke the removal action when the identity is not owned' {
            $script:removalInvoked = $false

            Invoke-OwnedRemoval -Name 'Remove-Widget' -Kind Widget -Identity 'widget-unowned' -Action {
                $script:removalInvoked = $true
            }

            $script:removalInvoked | Should -BeFalse
        }

        It 'clears ownership when the removal action succeeds' {
            Register-TestOwnedResource -Kind Widget -Identity 'widget-1'

            Invoke-OwnedRemoval -Name 'Remove-Widget' -Kind Widget -Identity 'widget-1' -Action {
                'removed'
            }

            $owned.Widget.Contains('widget-1') | Should -BeFalse
        }

        It 'leaves ownership intact when the removal action throws' {
            Register-TestOwnedResource -Kind Widget -Identity 'widget-1'

            Invoke-OwnedRemoval -Name 'Remove-Widget' -Kind Widget -Identity 'widget-1' -Action {
                throw 'simulated removal failure'
            }

            $owned.Widget.Contains('widget-1') | Should -BeTrue
            ($checks | Where-Object Name -EQ 'Remove-Widget').Status | Should -Be 'Failed'
        }
    }

    Context 'Rename, dependent-step failure, and cleanup ordering' {
        It 'still cleans up under the renamed identity after a read-back failure between rename and cleanup' {
            $widgetName = 'widget-1'
            Register-TestOwnedResource -Kind Widget -Identity $widgetName
            $script:removedIdentity = $null
            # The cleanup scriptblock captures $widgetName by reference (PowerShell late-binding),
            # so it picks up the renamed value when Invoke-RegisteredCleanup runs later.
            Register-CleanupAction -Name 'Remove-Widget' -Action {
                Invoke-OwnedRemoval -Name 'Remove-Widget' -Kind Widget -Identity $widgetName -Action {
                    $script:removedIdentity = $widgetName
                    'removed'
                }
            }

            $renamedWidgetName = 'widget-1-renamed'
            Update-TestOwnedResourceIdentity -Kind Widget -OldIdentity $widgetName -NewIdentity $renamedWidgetName
            $widgetName = $renamedWidgetName

            Add-MutationReadVerification -Name 'Rename-Widget:ReadBack' -Action {
                throw 'simulated read-back failure'
            } | Out-Null

            ($checks | Where-Object Name -EQ 'Verify:Rename-Widget:ReadBack').Status | Should -Be 'Failed'

            Invoke-RegisteredCleanup

            $script:removedIdentity | Should -Be $renamedWidgetName
            $owned.Widget.Contains($renamedWidgetName) | Should -BeFalse
        }
    }
}
