BeforeDiscovery {
    $script:namedObjectModule = New-Module -Name NamedObjectModificationTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhost { param([pscustomobject]$WebSession) }
        function Get-DMhostGroup { param([pscustomobject]$WebSession) }
        function Get-DMlunGroup { param([pscustomobject]$WebSession) }
        function Get-DMPortGroup { param([pscustomobject]$WebSession, [string]$VstoreId) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }
        function Set-DMLun {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([pscustomobject]$WebSession, [string]$LunName, [string]$NewName)
        }
        function Set-DMFileSystem {
            [CmdletBinding(SupportsShouldProcess = $true)]
            param([pscustomobject]$WebSession, [string]$FileSystemName, [string]$NewName)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\New-DMNamedObjectUpdate.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMPortGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMLun.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMFileSystem.ps1"

        Export-ModuleMember -Function 'Set-DM*', 'Rename-DM*'
    }
    Import-Module $script:namedObjectModule -Force
}

AfterAll {
    Remove-Module -Name NamedObjectModificationTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NamedObjectModificationTestModule {
Describe 'Named object Set commands' {
    It 'loads the shared update helper in the live integration runner' {
        $runnerPath = Join-Path $PSScriptRoot '..\..\Integration\Invoke-GetterIntegrityValidation.ps1'
        $runnerSource = Get-Content -LiteralPath $runnerPath -Raw
        $runnerSource | Should -Match "'New-DMNamedObjectUpdate\.ps1'"
        $runnerSource | Should -Match "'ConvertTo-DMCapacityBlocks\.ps1'"
    }

    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMhost { @([pscustomobject]@{ Id = 'host-01'; Name = 'host-old' }, [pscustomobject]@{ Id = 'host-02'; Name = 'taken' }) }
        Mock Get-DMhostGroup { @([pscustomobject]@{ Id = 'hg-01'; Name = 'hostgroup-old' }, [pscustomobject]@{ Id = 'hg-02'; Name = 'taken' }) }
        Mock Get-DMlunGroup { @([pscustomobject]@{ Id = 'lg-01'; Name = 'lungroup-old' }, [pscustomobject]@{ Id = 'lg-02'; Name = 'taken' }) }
        Mock Get-DMPortGroup { @([pscustomobject]@{ Id = 'pg-01'; Name = 'portgroup-old' }, [pscustomobject]@{ Id = 'pg-02'; Name = 'taken' }) }
        Mock Invoke-DeviceManager {
            $script:request = [pscustomobject]@{ Method = $Method; Resource = $Resource; Body = $BodyData }
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It '<Command> renames through <Resource>' -ForEach @(
        @{ Command = 'Set-DMHost';      Identity = @{ HostName = 'host-old' };           Resource = 'host/host-01?vstoreId=7'; Id = 'host-01' }
        @{ Command = 'Set-DMHostGroup'; Identity = @{ HostGroupName = 'hostgroup-old' }; Resource = 'hostgroup/hg-01?vstoreId=7'; Id = 'hg-01' }
        @{ Command = 'Set-DMLunGroup';  Identity = @{ LunGroupName = 'lungroup-old' };   Resource = 'lungroup/lg-01?vstoreId=7'; Id = 'lg-01' }
        @{ Command = 'Set-DMPortGroup'; Identity = @{ PortGroupName = 'portgroup-old' }; Resource = 'portgroup/pg-01?vstoreId=7'; Id = 'pg-01' }
    ) {
        $result = & $Command -WebSession $script:session -NewName 'renamed' -VstoreId '7' -Confirm:$false @Identity

        $result.Code | Should -Be 0
        $script:request.Method | Should -Be 'PUT'
        $script:request.Resource | Should -Be $Resource
        $script:request.Body.ID | Should -Be $Id
        $script:request.Body.NAME | Should -Be 'renamed'
    }

    It 'passes additional host API properties and an empty description' {
        $null = Set-DMHost -WebSession $script:session -HostName 'host-old' -Description '' `
            -ApiProperties @{ OPERATIONSYSTEM = 7; LOCATION = 'rack-01' } -Confirm:$false

        $script:request.Body.DESCRIPTION | Should -Be ''
        $script:request.Body.OPERATIONSYSTEM | Should -Be 7
        $script:request.Body.LOCATION | Should -Be 'rack-01'
    }

    It 'rejects duplicate names before calling the API' {
        { Set-DMHost -WebSession $script:session -HostName 'host-old' -NewName 'taken' -Confirm:$false } |
            Should -Throw '*already exists*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects reserved API properties' {
        { Set-DMHost -WebSession $script:session -HostName 'host-old' -ApiProperties @{ NAME = 'bypass' } -Confirm:$false } |
            Should -Throw '*reserved*'
    }

    It 'honors WhatIf' {
        $null = Set-DMPortGroup -WebSession $script:session -PortGroupName 'portgroup-old' -NewName 'renamed' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'Rename command delegation' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Set-DMHost { [pscustomobject]@{ Code = 0 } }
        Mock Set-DMHostGroup { [pscustomobject]@{ Code = 0 } }
        Mock Set-DMLunGroup { [pscustomobject]@{ Code = 0 } }
        Mock Set-DMPortGroup { [pscustomobject]@{ Code = 0 } }
        Mock Set-DMLun { [pscustomobject]@{ Code = 0 } }
        Mock Set-DMFileSystem { [pscustomobject]@{ Code = 0 } }
    }

    It '<Command> delegates to <SetCommand>' -ForEach @(
        @{ Command = 'Rename-DMHost';       SetCommand = 'Set-DMHost';       Parameters = @{ HostName = 'old'; NewName = 'new'; VstoreId = '7' } }
        @{ Command = 'Rename-DMHostGroup';  SetCommand = 'Set-DMHostGroup';  Parameters = @{ HostGroupName = 'old'; NewName = 'new'; VstoreId = '7' } }
        @{ Command = 'Rename-DMLunGroup';   SetCommand = 'Set-DMLunGroup';   Parameters = @{ LunGroupName = 'old'; NewName = 'new'; VstoreId = '7' } }
        @{ Command = 'Rename-DMPortGroup';  SetCommand = 'Set-DMPortGroup';  Parameters = @{ PortGroupName = 'old'; NewName = 'new'; VstoreId = '7' } }
        @{ Command = 'Rename-DMLun';        SetCommand = 'Set-DMLun';        Parameters = @{ LunName = 'old'; NewName = 'new' } }
        @{ Command = 'Rename-DMFileSystem'; SetCommand = 'Set-DMFileSystem'; Parameters = @{ FileSystemName = 'old'; NewName = 'new' } }
    ) {
        $result = & $Command -WebSession $script:session -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        Should -Invoke $SetCommand -Times 1 -Exactly
    }

    It 'does not delegate under WhatIf' {
        $null = Rename-DMHost -WebSession $script:session -HostName 'old' -NewName 'new' -WhatIf

        Should -Invoke Set-DMHost -Times 0 -Exactly
    }
}
}
