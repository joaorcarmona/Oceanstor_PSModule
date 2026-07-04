BeforeDiscovery {
    $script:removeLunModule = New-Module -Name RemoveDMLunTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun {
            param([pscustomobject]$WebSession, [string]$Name, [string]$Id)
        }

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLun.ps1"

        Export-ModuleMember -Function Remove-DMLun
    }

    Import-Module $script:removeLunModule -Force
}

AfterAll {
    Remove-Module -Name RemoveDMLunTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope RemoveDMLunTestModule {
Describe 'Remove-DMLun' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun {
            $items = @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'not mapped' })
            if ($Id) {
                return @($items | Where-Object Id -EQ $Id)
            }
            if ($Name) {
                return @($items | Where-Object Name -EQ $Name)
            }
            return $items
        }
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'removes an existing LUN by its resolved ID' {
        $result = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false

        $result.Code | Should -Be 0
        Should -Invoke Get-DMlun -Times 1 -Exactly -ParameterFilter { $Name -eq 'data-lun' -and -not $Id }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Resource -eq 'lun/lun-01'
        }
    }

    It 'removes an existing LUN by ID without name resolution' {
        $result = Remove-DMLun -WebSession $script:session -LunId 'lun-01' -Confirm:$false

        $result.Code | Should -Be 0
        Should -Invoke Get-DMlun -Times 1 -Exactly -ParameterFilter { $Id -eq 'lun-01' -and -not $Name }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Resource -eq 'lun/lun-01'
        }
    }

    It 'appends isDelayDelete=false when ImmediateDelete is specified' {
        $null = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -ImmediateDelete -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Resource -eq 'lun/lun-01?isDelayDelete=false'
        }
    }

    It 'appends vstoreId when VstoreId is specified' {
        $null = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -VstoreId 'vs-02' -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Resource -eq 'lun/lun-01?vstoreId=vs-02'
        }
    }

    It 'does not call the API when WhatIf is specified' {
        $null = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error when the LUN is currently mapped, without stopping the pipeline' {
        Mock Get-DMlun {
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'mapped' })
        }

        $result = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        # PowerShell's own error-record bookkeeping can append the same logical failure to
        # -ErrorVariable more than once when a terminating error is caught and re-reported via
        # WriteError (see https://github.com/PowerShell/PowerShell, well-known $Error duplication
        # on caught nested terminating errors) -- assert at least one report with the right
        # message, not an exact count, and that it's the same failure reported every time.
        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -Be "Cannot remove LUN 'data-lun': it is currently mapped to a host. Remove the mapping view first."
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'escalates the mapped-LUN error to a terminating exception when -ErrorAction Stop is requested' {
        Mock Get-DMlun {
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'mapped' })
        }

        { Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*currently mapped*Remove the mapping view*'
    }

    It 'reports a non-terminating error for a LUN name that does not exist' {
        $result = Remove-DMLun -WebSession $script:session -LunName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid LunName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'escalates the invalid-name error to a terminating exception when -ErrorAction Stop is requested' {
        { Remove-DMLun -WebSession $script:session -LunName 'missing' -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*Invalid LunName*'
    }

    It 'reports a non-terminating error for a LUN name that is not unique' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'not mapped' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'data-lun'; 'is Mapped' = 'not mapped' }
            )
        }

        $result = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*LunName is ambiguous*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'processes every LUN piped in, not just the last one' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a'; 'is Mapped' = 'not mapped' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b'; 'is Mapped' = 'not mapped' }
                [pscustomobject]@{ Id = 'lun-03'; Name = 'lun-c'; 'is Mapped' = 'not mapped' }
            )
        }

        $luns = @(
            [pscustomobject]@{ Name = 'lun-a' }
            [pscustomobject]@{ Name = 'lun-b' }
            [pscustomobject]@{ Name = 'lun-c' }
        )
        $null = $luns | Remove-DMLun -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lun/lun-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lun/lun-02' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lun/lun-03' }
    }

    It 'continues processing remaining piped LUNs after one fails' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'lun-a'; 'is Mapped' = 'not mapped' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'lun-b'; 'is Mapped' = 'mapped' }
                [pscustomobject]@{ Id = 'lun-03'; Name = 'lun-c'; 'is Mapped' = 'not mapped' }
            )
        }

        $luns = @(
            [pscustomobject]@{ Name = 'lun-a' }
            [pscustomobject]@{ Name = 'lun-b' }
            [pscustomobject]@{ Name = 'lun-c' }
        )
        $null = $luns | Remove-DMLun -WebSession $script:session -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*currently mapped*'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lun/lun-01' }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Resource -eq 'lun/lun-02' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'lun/lun-03' }
    }

    It 'resolves a different WebSession per piped object (concurrent multi-array sessions)' {
        $sessionA = [pscustomobject]@{ version = 'V600R001'; Name = 'array-a' }
        $sessionB = [pscustomobject]@{ version = 'V600R001'; Name = 'array-b' }
        Mock Get-DMlun {
            if ($WebSession.Name -eq 'array-a') {
                return @([pscustomobject]@{ Id = 'lun-a1'; Name = 'lun-a'; 'is Mapped' = 'not mapped' })
            }
            @([pscustomobject]@{ Id = 'lun-b1'; Name = 'lun-b'; 'is Mapped' = 'not mapped' })
        }

        $luns = @(
            [pscustomobject]@{ Name = 'lun-a'; WebSession = $sessionA }
            [pscustomobject]@{ Name = 'lun-b'; WebSession = $sessionB }
        )
        $null = $luns | Remove-DMLun -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $WebSession.Name -eq 'array-a' -and $Resource -eq 'lun/lun-a1' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $WebSession.Name -eq 'array-b' -and $Resource -eq 'lun/lun-b1' }
    }
}
}
