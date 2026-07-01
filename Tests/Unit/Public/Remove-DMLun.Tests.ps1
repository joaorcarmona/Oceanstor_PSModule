BeforeDiscovery {
    $script:removeLunModule = New-Module -Name RemoveDMLunTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun {
            param([pscustomobject]$WebSession)
        }

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource
            )
        }

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
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'not mapped' })
        }
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'removes an existing LUN by its resolved ID' {
        $result = Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false

        $result.Code | Should -Be 0
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

    It 'throws a readable error when the LUN is currently mapped' {
        Mock Get-DMlun {
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'mapped' })
        }

        { Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false } |
            Should -Throw '*currently mapped*Remove the mapping view*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a LUN name that does not exist' {
        { Remove-DMLun -WebSession $script:session -LunName 'missing' -Confirm:$false } |
            Should -Throw '*Invalid LunName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a LUN name that is not unique' {
        Mock Get-DMlun {
            @(
                [pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun'; 'is Mapped' = 'not mapped' }
                [pscustomobject]@{ Id = 'lun-02'; Name = 'data-lun'; 'is Mapped' = 'not mapped' }
            )
        }

        { Remove-DMLun -WebSession $script:session -LunName 'data-lun' -Confirm:$false } |
            Should -Throw '*LunName is ambiguous*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
