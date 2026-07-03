BeforeDiscovery {
    $script:testModule = New-Module -Name GetDMDiskByStoragePoolTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMstoragePool { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMdisk { param($WebSession, $StoragePool, $StoragePoolName, $StoragePoolId) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMDiskByStoragePool.ps1"

        Export-ModuleMember -Function Get-DMDiskByStoragePool
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name GetDMDiskByStoragePoolTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope GetDMDiskByStoragePoolTestModule {
Describe 'Get-DMDiskByStoragePool (legacy wrapper)' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:storagePool = [pscustomobject]@{ Id = 'pool-01'; Name = 'performance' }

        Mock Get-DMstoragePool {
            param($WebSession, $Name)
            $pools = @([pscustomobject]@{ Id = 'pool-01'; Name = 'performance' })
            if ($Name) { return @($pools | Where-Object Name -Like $Name) }
            $pools
        }
    }

    It 'forwards a piped StoragePool object to Get-DMdisk' {
        Mock Get-DMdisk { [pscustomobject]@{ id = 'disk-01' } }

        $result = @(Get-DMDiskByStoragePool -WebSession $script:session -StoragePool $script:storagePool)

        $result[0].id | Should -Be 'disk-01'
        Should -Invoke Get-DMdisk -Times 1 -Exactly -ParameterFilter {
            $StoragePool -eq $script:storagePool -and $WebSession -eq $script:session
        }
    }

    It 'forwards StoragePoolName to Get-DMdisk after resolving it' {
        Mock Get-DMdisk { [pscustomobject]@{ id = 'disk-01' } }

        $result = @(Get-DMDiskByStoragePool -WebSession $script:session -StoragePoolName 'performance')

        $result[0].id | Should -Be 'disk-01'
        Should -Invoke Get-DMdisk -Times 1 -Exactly -ParameterFilter {
            $StoragePoolName -eq 'performance' -and $WebSession -eq $script:session
        }
    }

    It 'rejects a StoragePoolName that does not exist, before calling Get-DMdisk' {
        Mock Get-DMdisk { [pscustomobject]@{ id = 'disk-01' } }

        { Get-DMDiskByStoragePool -WebSession $script:session -StoragePoolName 'missing' } |
            Should -Throw '*Invalid StoragePoolName*'

        Should -Invoke Get-DMdisk -Times 0 -Exactly
    }

    It 'forwards StoragePoolId to Get-DMdisk without validating it first' {
        Mock Get-DMdisk { [pscustomobject]@{ id = 'disk-03' } }

        $result = @(Get-DMDiskByStoragePool -WebSession $script:session -StoragePoolId 'pool-99')

        $result[0].id | Should -Be 'disk-03'
        Should -Invoke Get-DMstoragePool -Times 0 -Exactly
        Should -Invoke Get-DMdisk -Times 1 -Exactly -ParameterFilter {
            $StoragePoolId -eq 'pool-99' -and $WebSession -eq $script:session
        }
    }

    It 'exposes completion metadata for StoragePoolName' {
        $command = Get-Command Get-DMDiskByStoragePool
        @($command.Parameters['StoragePoolName'].Attributes |
            Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
            Should -BeGreaterThan 0 -Because 'Get-DMDiskByStoragePool -StoragePoolName should support tab completion'
    }

    It 'warns about deprecation' {
        Mock Get-DMdisk { [pscustomobject]@{ id = 'disk-01' } }

        Get-DMDiskByStoragePool -WebSession $script:session -StoragePool $script:storagePool -WarningVariable warnings -WarningAction SilentlyContinue | Out-Null

        $warnings.Count | Should -Be 1
        $warnings[0] | Should -Match 'deprecated'
    }
}
}
