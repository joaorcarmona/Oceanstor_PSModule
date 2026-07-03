BeforeDiscovery {
    $script:testModule = New-Module -Name AddDMPortToPortGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMPortGroup          { param([pscustomobject]$WebSession) }
        function Get-DMPortGroupCandidate { param([pscustomobject]$WebSession, [string]$PortType) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMPortToPortGroup.ps1"

        Export-ModuleMember -Function Add-DMPortToPortGroup
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name AddDMPortToPortGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope AddDMPortToPortGroupTestModule {
Describe 'Add-DMPortToPortGroup' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMPortGroup {
            @([pscustomobject]@{ Id = 'pg-01'; Name = 'fc-front-end' })
        }
        Mock Get-DMPortGroupCandidate {
            @([pscustomobject]@{ Id = 'port-01'; Name = 'CTE0.A.IOM0.P0'; ObjectType = 212 })
        }
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'associates a port with a port group and calls the API exactly once' {
        $result = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -Confirm:$false

        $result.Code | Should -Be 0
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'POST' -and $Resource -eq 'port/associate/portgroup' -and
            $BodyData.ID -eq 'pg-01' -and $BodyData.ASSOCIATEOBJID -eq 'port-01'
        }
    }

    It 'calls Get-DMPortGroup only once per invocation (no redundant API round-trip)' {
        $null = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -Confirm:$false

        Should -Invoke Get-DMPortGroup -Times 1 -Exactly
    }

    It 'calls Get-DMPortGroupCandidate only once per invocation (no redundant API round-trip)' {
        $null = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -Confirm:$false

        Should -Invoke Get-DMPortGroupCandidate -Times 1 -Exactly
    }

    It 'does not call the API when WhatIf is specified' {
        $null = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for a port group name that does not exist' {
        $result = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'missing' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable addErrors

        $result | Should -BeNullOrEmpty
        $addErrors.Count | Should -BeGreaterOrEqual 1
        ($addErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid PortGroupName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for a port name that does not exist for the given type' {
        $result = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable addErrors

        $result | Should -BeNullOrEmpty
        $addErrors.Count | Should -BeGreaterOrEqual 1
        ($addErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid PortName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'includes vstoreId in the body when VstoreId is specified' {
        $null = Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -VstoreId 'vs-02' -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $BodyData.vstoreId -eq 'vs-02'
        }
    }

    It 'associates every port piped in, not just the last one' {
        Mock Get-DMPortGroupCandidate {
            @([pscustomobject]@{ Id = 'port-01'; Name = 'CTE0.A.IOM0.P0'; ObjectType = 212 }, [pscustomobject]@{ Id = 'port-02'; Name = 'CTE0.A.IOM0.P1'; ObjectType = 212 })
        }

        $ports = @([pscustomobject]@{ Name = 'CTE0.A.IOM0.P0' }, [pscustomobject]@{ Name = 'CTE0.A.IOM0.P1' })
        $null = $ports | Add-DMPortToPortGroup -WebSession $script:session -PortGroupName 'fc-front-end' -PortType FibreChannel -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $BodyData.ASSOCIATEOBJID -eq 'port-01' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $BodyData.ASSOCIATEOBJID -eq 'port-02' }
    }
}
}
