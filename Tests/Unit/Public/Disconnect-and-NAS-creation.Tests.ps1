BeforeDiscovery {
    $script:testModule = New-Module -Name DisconnectAndNasTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMSystem { param([pscustomobject]$WebSession) }
        function Get-DMFileSystem { param([pscustomobject]$WebSession) }
        function Get-DMShare { param([pscustomobject]$WebSession, [string]$ShareType) }
        function Get-DMdnsServer { param([pscustomobject]$WebSession) }
        function Write-DMError { param($SessionError) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Test-IPv4Address.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorNFSShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorNFSclient.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Disconnect-deviceManager.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMnfsShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMnfsClient.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMdnsServer.ps1"

        Export-ModuleMember -Function 'Disconnect-deviceManager', 'New-DMnfs*', 'Set-DMdnsServer'
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name DisconnectAndNasTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope DisconnectAndNasTestModule {
Describe 'Disconnect-deviceManager' {
    BeforeEach {
        $script:session = [pscustomobject]@{ Hostname = 'oceanstor.test'; version = 'V600R001' }
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ code = 0; description = '0' } }
        }
    }

    It 'issues a DELETE to the sessions resource' {
        Disconnect-deviceManager -WebSession $script:session

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'DELETE' -and $Resource -eq 'sessions'
        }
    }

    It 'clears the global deviceManager variable when no WebSession is supplied' {
        $global:deviceManager = $script:session

        Disconnect-deviceManager

        $global:deviceManager | Should -BeNullOrEmpty
    }

    It 'does not clear the global variable when WebSession is supplied explicitly' {
        $global:deviceManager = [pscustomobject]@{ Hostname = 'other.test'; version = 'V600R001' }

        Disconnect-deviceManager -WebSession $script:session

        $global:deviceManager | Should -Not -BeNullOrEmpty
        $global:deviceManager.Hostname | Should -Be 'other.test'
    }

    It 'throws when no session is available' {
        { Disconnect-deviceManager } | Should -Throw '*No active OceanStor session*'
    }

    It 'throws on a non-zero API error code' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ code = -401; description = 'Not authenticated' } }
        }

        { Disconnect-deviceManager -WebSession $script:session } | Should -Throw '*Logout failed*'
    }
}

Describe 'New-DMnfsShare' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:nfsMethod = $Method
            $script:nfsResource = $Resource
            $script:nfsBody = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{ ID = 'nfs-01'; NAME = '/documents/'; CHARACTERENCODING = 0 }
            }
        }
    }

    It 'creates an NFS share with the correct API call' {
        $result = New-DMnfsShare -WebSession $script:session -sharepath '/documents/' -FileSystemId 'fs-01'

        $result.GetType().Name | Should -Be 'OceanStorNFSShare'
        $script:nfsMethod | Should -Be 'POST'
        $script:nfsResource | Should -Be 'NFSSHARE'
        $script:nfsBody.SHAREPATH | Should -Be '/documents/'
        $script:nfsBody.FSID | Should -Be 'fs-01'
        $script:nfsBody.CHARACTERENCODING | Should -Be 0
    }

    It 'includes dTree ID when supplied' {
        New-DMnfsShare -WebSession $script:session -sharepath '/documents/sub/' -FileSystemId 'fs-01' -dTree 'dtree-01'

        $script:nfsBody.DTREEID | Should -Be 'dtree-01'
    }

    It 'returns the API error on failure' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ Code = -1; Description = 'Share exists' } }
        }

        $result = New-DMnfsShare -WebSession $script:session -sharepath '/documents/' -FileSystemId 'fs-01'

        $result.Code | Should -Be -1
    }
}

Describe 'New-DMnfsClient' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMShare { @([pscustomobject]@{ Id = 'nfs-01'; Name = '/documents/' }) }
        Mock Invoke-DeviceManager {
            $script:clientMethod = $Method
            $script:clientResource = $Resource
            $script:clientBody = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{ ID = 'client-01'; NAME = '10.0.0.0/24'; ACCESSVAL = 0; CHARSET = 0 }
            }
        }
    }

    It 'creates an NFS client with default read-only permission' {
        New-DMnfsClient -WebSession $script:session -clientName '10.0.0.0/24' -shareId 'nfs-01'

        $script:clientMethod | Should -Be 'POST'
        $script:clientResource | Should -Be 'NFS_SHARE_AUTH_CLIENT'
        $script:clientBody.NAME | Should -Be '10.0.0.0/24'
        $script:clientBody.PARENTID | Should -Be 'nfs-01'
        $script:clientBody.ACCESSVAL | Should -Be 0
        $script:clientBody.ROOTSQUASH | Should -Be 0
        $script:clientBody.ALLSQUASH | Should -Be 1
    }

    It 'creates an NFS client with read-write and no-root-squash' {
        New-DMnfsClient -WebSession $script:session -clientName '10.0.0.1' -shareId 'nfs-01' -Permission 'read-write' -rootPermissionConstraint 'no_root_squash'

        $script:clientBody.ACCESSVAL | Should -Be 1
        $script:clientBody.ROOTSQUASH | Should -Be 1
    }

    It 'includes vStore ID when supplied' {
        New-DMnfsClient -WebSession $script:session -clientName '10.0.0.1' -shareId 'nfs-01' -vStoreId 7

        $script:clientBody.vstoreId | Should -Be 7
    }
}

Describe 'Set-DMdnsServer' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:dnsMethod = $Method
            $script:dnsResource = $Resource
            $script:dnsBody = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ code = 0 } }
        }
    }

    It 'sends a PUT with the DNS address array and returns the API error object' {
        $result = Set-DMdnsServer -WebSession $script:session -DNSserver @('8.8.8.8', '1.1.1.1')

        $script:dnsMethod | Should -Be 'PUT'
        $script:dnsResource | Should -Be 'dns_server'
        $script:dnsBody.ADDRESS | Should -Be @('8.8.8.8', '1.1.1.1')
        $result.code | Should -Be 0
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'throws on an invalid IP address' {
        { Set-DMdnsServer -WebSession $script:session -DNSserver @('8.8.8.8', '999.1.1.1') } |
            Should -Throw "*'999.1.1.1' is not a valid IPv4 address*"

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'returns the API error object when the update fails' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ error = [pscustomobject]@{ code = -1 } }
        }

        $result = Set-DMdnsServer -WebSession $script:session -DNSserver @('8.8.8.8')

        $result.code | Should -Be -1
    }
}
}
