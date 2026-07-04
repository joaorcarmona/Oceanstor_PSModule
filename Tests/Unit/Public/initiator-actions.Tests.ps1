BeforeDiscovery {
    $script:initiatorModule = New-Module -Name InitiatorActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhost { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMHostInitiator {
            param(
                [pscustomobject]$WebSession,
                [string]$InitiatorType,
                [string]$HostId,
                [switch]$FreeInitiators,
                [switch]$All
            )
        }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Test-WWNAddress.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorFC.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorISCSI.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorHostinitiatorNVMe.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMFiberChannelInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMIscsiInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMNvmeInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMFiberChannelInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMIscsiInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMNvmeInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFiberChannelInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMFiberChannelInitiatorFromHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMIscsiInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMIscsiInitiatorFromHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMNvmeInitiator.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMNvmeInitiatorFromHost.ps1"

        Export-ModuleMember -Function '*-DMFiberChannelInitiator*', '*-DMIscsiInitiator*', '*-DMNvmeInitiator*'
    }

    Import-Module $script:initiatorModule -Force
}

AfterAll {
    Remove-Module -Name InitiatorActionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope InitiatorActionsTestModule {
Describe 'Initiator creation and query commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMhost { @([pscustomobject]@{ Id = 'host-01'; Name = 'server01' } | Where-Object Name -EQ $Name) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            switch ($Resource) {
                'fc_initiator' {
                    [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = $BodyData.ID; TYPE = 223; PARENTID = $BodyData.PARENTID } }
                }
                'iscsi_initiator' {
                    [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = $BodyData.ID; TYPE = 222; USECHAP = $BodyData.USECHAP } }
                }
                { $_ -like 'NVMe_over_RoCE_initiator*' } {
                    [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @([pscustomobject]@{ ID = if ($BodyData) { $BodyData.ID } else { 'nqn.test' }; TYPE = 57870; ISFREE = 'true'; RUNNINGSTATUS = 28 }) }
                }
                default { [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() } }
            }
        }
        Mock Get-DMHostInitiator {
            if ($InitiatorType -eq 'FibreChannel') {
                return @([OceanstorHostinitiatorFC]::new([pscustomobject]@{ ID = '10000090FA123456'; TYPE = 223 }, $script:session))
            }
            return @([OceanstorHostinitiatorISCSI]::new([pscustomobject]@{ ID = 'iqn.2026-05.example:server01'; TYPE = 222 }, $script:session))
        }
    }

    It 'creates a Fibre Channel initiator and associates it with a host' {
        $result = New-DMFiberChannelInitiator -WebSession $script:session -WWN '10000090FA123456' -Name 'fc01' -HostName 'server01'

        $result.GetType().Name | Should -Be 'OceanstorHostinitiatorFC'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'fc_initiator'
        $script:request.ID | Should -Be '10000090FA123456'
        $script:request.PARENTTYPE | Should -Be 21
        $script:request.PARENTID | Should -Be 'host-01'
    }

    It 'rejects an invalid Fibre Channel WWN before REST creation' {
        { New-DMFiberChannelInitiator -WebSession $script:session -WWN '0000000000000000' } |
            Should -Throw '*WWN must contain*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'creates an iSCSI initiator with CHAP settings' {
        $result = New-DMIscsiInitiator -WebSession $script:session -Identifier 'iqn.2026-05.example:server01' -UseChap -ChapName 'chap-user' -ChapPassword 'SecretPass123!'

        $result.GetType().Name | Should -Be 'OceanstorHostinitiatorISCSI'
        $script:resource | Should -Be 'iscsi_initiator'
        $script:request.USECHAP | Should -BeTrue
        $script:request.CHAPNAME | Should -Be 'chap-user'
        $script:request.CHAPPASSWORD | Should -Be 'SecretPass123!'
    }

    It 'creates an NVMe over RoCE initiator' {
        $result = New-DMNvmeInitiator -WebSession $script:session -Nqn 'nqn.2026-05.example:host01' -Name 'nvme01'

        $result.GetType().Name | Should -Be 'OceanstorHostinitiatorNVMe'
        $script:resource | Should -Be 'NVMe_over_RoCE_initiator'
        $script:request.ID | Should -Be 'nqn.2026-05.example:host01'
    }

    It 'uses the existing generic getter for FC and iSCSI initiators' {
        (Get-DMFiberChannelInitiator -WebSession $script:session -FreeInitiators)[0].Id | Should -Be '10000090FA123456'
        (Get-DMIscsiInitiator -WebSession $script:session -HostName 'server01')[0].Id | Should -Be 'iqn.2026-05.example:server01'

        Should -Invoke Get-DMHostInitiator -ParameterFilter { $InitiatorType -eq 'FibreChannel' -and $FreeInitiators }
        Should -Invoke Get-DMHostInitiator -ParameterFilter { $InitiatorType -eq 'ISCSI' -and $HostId -eq 'host-01' }
    }

    It 'queries NVMe initiators associated with a host' {
        $result = Get-DMNvmeInitiator -WebSession $script:session -HostName 'server01'

        $result[0].GetType().Name | Should -Be 'OceanstorHostinitiatorNVMe'
        $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
            Should -Be @('Id', 'Type', 'Host Name', 'Running Status', 'Is Free')
        $script:resource | Should -BeLike 'NVMe_over_RoCE_initiator/associate?ASSOCIATEOBJTYPE=21&ASSOCIATEOBJID=host-01*'
    }

    It 'returns no NVMe objects when the API contains no data property' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } } }

        @(Get-DMNvmeInitiator -WebSession $script:session) | Should -BeNullOrEmpty
    }
}

Describe 'Initiator removal commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMhost { @([pscustomobject]@{ Id = 'host-01'; Name = 'server01' } | Where-Object Name -EQ $Name) }
        Mock Get-DMFiberChannelInitiator { @([pscustomobject]@{ Id = '10000090FA123456' }) }
        Mock Get-DMIscsiInitiator { @([pscustomobject]@{ Id = 'iqn.2026-05.example:server01' }) }
        Mock Get-DMNvmeInitiator { @([pscustomobject]@{ Id = 'nqn.2026-05.example:host01' }) }
        Mock Get-DMHostInitiator {
            if ($InitiatorType -eq 'FibreChannel') {
                return @([pscustomobject]@{ Id = '10000090FA123456' })
            }
            return @([pscustomobject]@{ Id = 'iqn.2026-05.example:server01' })
        }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'nqn.2026-05.example:host01' }) }
            }
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It '<Command> removes a free initiator through the protocol REST operation' -TestCases @(
        @{ Command = 'Remove-DMFiberChannelInitiator'; Parameters = @{ WWN = '10000090FA123456'; VstoreId = '7' }; Resource = 'fc_initiator/10000090FA123456?vstoreId=7'; HasBody = $false }
        @{ Command = 'Remove-DMIscsiInitiator'; Parameters = @{ Identifier = 'iqn.2026-05.example:server01'; VstoreId = '7' }; Resource = 'iscsi_initiator/iqn.2026-05.example:server01?vstoreId=7'; HasBody = $false }
        @{ Command = 'Remove-DMNvmeInitiator'; Parameters = @{ Nqn = 'nqn.2026-05.example:host01'; VstoreId = '7' }; Resource = 'NVMe_over_RoCE_initiator'; HasBody = $true }
    ) {
        param($Command, $Parameters, $Resource, $HasBody)

        $result = & $Command -WebSession $script:session -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be $Resource
        if ($HasBody) {
            $script:request.ID | Should -Be $Parameters.Nqn
            $script:request.vstoreId | Should -Be '7'
        }
    }

    It '<Command> removes an initiator association from a host' -TestCases @(
        @{ Command = 'Remove-DMFiberChannelInitiatorFromHost'; Parameters = @{ HostName = 'server01'; WWN = '10000090FA123456' }; Resource = 'fc_initiator/remove_fc_from_host'; Id = '10000090FA123456' }
        @{ Command = 'Remove-DMIscsiInitiatorFromHost'; Parameters = @{ HostName = 'server01'; Identifier = 'iqn.2026-05.example:server01' }; Resource = 'iscsi_initiator/remove_iscsi_from_host'; Id = 'iqn.2026-05.example:server01' }
        @{ Command = 'Remove-DMNvmeInitiatorFromHost'; Parameters = @{ HostName = 'server01'; Nqn = 'nqn.2026-05.example:host01' }; Resource = 'host/remove_associate'; Id = 'nqn.2026-05.example:host01' }
    ) {
        param($Command, $Parameters, $Resource, $Id)

        $result = & $Command -WebSession $script:session -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be $Resource
        if ($Command -eq 'Remove-DMNvmeInitiatorFromHost') {
            $script:request.ID | Should -Be 'host-01'
            $script:request.ASSOCIATEOBJTYPE | Should -Be 57870
            $script:request.ASSOCIATEOBJID | Should -Be $Id
        } else {
            $script:request.ID | Should -Be $Id
        }
    }

    It 'honors WhatIf for destructive initiator operations' {
        $null = Remove-DMIscsiInitiator -WebSession $script:session -Identifier 'iqn.2026-05.example:server01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes every free Fibre Channel initiator piped in, not just the last one' {
        Mock Get-DMFiberChannelInitiator {
            @([pscustomobject]@{ Id = 'wwn-a' }, [pscustomobject]@{ Id = 'wwn-b' })
        }
        $resources = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-DeviceManager {
            $resources.Add($Resource)
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $items = @([pscustomobject]@{ Id = 'wwn-a' }, [pscustomobject]@{ Id = 'wwn-b' })
        $null = $items | Remove-DMFiberChannelInitiator -WebSession $script:session -Confirm:$false

        $resources | Should -Contain 'fc_initiator/wwn-a'
        $resources | Should -Contain 'fc_initiator/wwn-b'
    }

    It 'removes every Fibre Channel initiator piped in from the same host, not just the last one' {
        Mock Get-DMHostInitiator {
            @([pscustomobject]@{ Id = 'wwn-a' }, [pscustomobject]@{ Id = 'wwn-b' })
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $items = @([pscustomobject]@{ Id = 'wwn-a' }, [pscustomobject]@{ Id = 'wwn-b' })
        $null = $items | Remove-DMFiberChannelInitiatorFromHost -WebSession $script:session -HostName 'server01' -Confirm:$false

        ($requests | Where-Object { $_.Body.ID -eq 'wwn-a' }).Count | Should -Be 1
        ($requests | Where-Object { $_.Body.ID -eq 'wwn-b' }).Count | Should -Be 1
    }
}
}
