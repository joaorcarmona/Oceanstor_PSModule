BeforeDiscovery {
    $script:storagePoolRenameModule = New-Module -Name StoragePoolRenameTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMstoragePool { param([pscustomobject]$WebSession, [string]$Name) }
        function Invoke-DeviceManager {
            param([pscustomobject]$WebSession, [string]$Method, [string]$Resource, [hashtable]$BodyData)
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\New-DMNamedObjectUpdate.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMstoragePool.ps1"

        Export-ModuleMember -Function 'Rename-DMstoragePool'
    }
    Import-Module $script:storagePoolRenameModule -Force
}

AfterAll {
    Remove-Module -Name StoragePoolRenameTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope StoragePoolRenameTestModule {
    Describe 'Rename-DMstoragePool' {
        BeforeEach {
            $script:session = [pscustomobject]@{ version = 'V600R001' }
            Mock Get-DMstoragePool {
                @(
                    [pscustomobject]@{ Id = 'pool-01'; Name = 'Pool_01' }
                    [pscustomobject]@{ Id = 'pool-02'; Name = 'Pool_taken' }
                )
            }
            Mock Invoke-DeviceManager {
                $script:request = [pscustomobject]@{ Method = $Method; Resource = $Resource; Body = $BodyData }
                [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
            }
        }

        It 'issues PUT storagepool/{id} changing only the NAME label' {
            $result = Rename-DMstoragePool -WebSession $script:session -StoragePoolName 'Pool_01' -NewName 'Pool_01_archive' -Confirm:$false

            $result.Code | Should -Be 0
            $script:request.Method | Should -Be 'PUT'
            $script:request.Resource | Should -Be 'storagepool/pool-01'
            $script:request.Body.ID | Should -Be 'pool-01'
            $script:request.Body.NAME | Should -Be 'Pool_01_archive'
            $script:request.Body.Keys | Should -Not -Contain 'DESCRIPTION'
        }

        It 'accepts a pool piped in by property name' {
            $null = [pscustomobject]@{ Name = 'Pool_01' } | Rename-DMstoragePool -WebSession $script:session -NewName 'Pool_01_archive' -Confirm:$false

            $script:request.Resource | Should -Be 'storagepool/pool-01'
            $script:request.Body.NAME | Should -Be 'Pool_01_archive'
        }

        It 'honors WhatIf and performs no API call' {
            $null = Rename-DMstoragePool -WebSession $script:session -StoragePoolName 'Pool_01' -NewName 'Pool_01_archive' -WhatIf

            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'reports a non-terminating error for an unknown pool name and makes no API call' {
            $result = Rename-DMstoragePool -WebSession $script:session -StoragePoolName 'missing' -NewName 'whatever' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable renameErrors

            $result | Should -BeNullOrEmpty
            $renameErrors.Count | Should -BeGreaterOrEqual 1
            ($renameErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid storage pool name*'
            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'rejects a NewName that collides with an existing pool and makes no API call' {
            $result = Rename-DMstoragePool -WebSession $script:session -StoragePoolName 'Pool_01' -NewName 'Pool_taken' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable renameErrors

            $result | Should -BeNullOrEmpty
            $renameErrors.Count | Should -BeGreaterOrEqual 1
            ($renameErrors.Exception.Message | Select-Object -Unique) | Should -BeLike "*already exists*"
            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'rejects an illegal NewName at parameter binding' {
            { Rename-DMstoragePool -WebSession $script:session -StoragePoolName 'Pool_01' -NewName 'bad name!' -Confirm:$false } |
                Should -Throw
            Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
        }

        It 'is high-impact and supports ShouldProcess' {
            $command = Get-Command Rename-DMstoragePool
            $command.Parameters.ContainsKey('WhatIf') | Should -BeTrue
            $attribute = $command.ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attribute.ConfirmImpact | Should -Be 'High'
        }
    }
}
