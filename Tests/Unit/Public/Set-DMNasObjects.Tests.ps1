BeforeDiscovery {
    $script:setNasModule = New-Module -Name SetNasObjectsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMFileSystem { param([pscustomobject]$WebSession) }
        function Get-DMShare { param([pscustomobject]$WebSession, [string]$ShareType) }
        function Get-DMnfsFileClient { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMdTree.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMnfsShare.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMnfsClient.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMCifsShare.ps1"

        Export-ModuleMember -Function 'Set-DM*'
    }
    Import-Module $script:setNasModule -Force
}

AfterAll {
    Remove-Module -Name SetNasObjectsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SetNasObjectsTestModule {
Describe 'Set-DMdTree' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fs-01@4'; NAME = 'archive' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'modifies the quota switch of a resolved dTree' {
        $result = Set-DMdTree -WebSession $script:session -FileSystemName 'documents' -DTreeName 'archive' -QuotaSwitch enabled -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'QUOTATREE/fs-01@4'
        $script:request.ID | Should -Be 'fs-01@4'
        $script:request.QUOTASWITCH | Should -BeTrue
        $script:request.vstoreId | Should -Be '7'
    }

    It 'translates NewName and SecurityStyle to API values' {
        $null = Set-DMdTree -WebSession $script:session -FileSystemName 'documents' -DTreeName 'archive' -NewName 'renamed' -SecurityStyle NTFS -Confirm:$false

        $script:request.NAME | Should -Be 'renamed'
        $script:request.securityStyle | Should -Be 2
    }

    It 'rejects a modify call with no changes specified' {
        $result = Set-DMdTree -WebSession $script:session -FileSystemName 'documents' -DTreeName 'archive' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Specify at least one of*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects an unknown dTree name' {
        $result = Set-DMdTree -WebSession $script:session -FileSystemName 'documents' -DTreeName 'missing' -QuotaSwitch disabled -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid DTreeName*'
    }

    It 'does not modify when WhatIf is specified' {
        $null = Set-DMdTree -WebSession $script:session -FileSystemName 'documents' -DTreeName 'archive' -QuotaSwitch enabled -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Method -eq 'GET' }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Method -eq 'PUT' }
    }
}

Describe 'Set-DMnfsShare' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMShare { @([pscustomobject]@{ Id = 'nfs-01'; 'Share Path' = '/documents/' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'modifies the description of a resolved NFS share' {
        $result = Set-DMnfsShare -WebSession $script:session -SharePath '/documents/' -Description 'Finance archive' -PrivateShare -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'NFSSHARE/nfs-01?sharePrivate=1&vstoreId=7'
        $script:request.ID | Should -Be 'nfs-01'
        $script:request.DESCRIPTION | Should -Be 'Finance archive'
    }

    It 'translates CharacterEncoding to API values' {
        $null = Set-DMnfsShare -WebSession $script:session -SharePath '/documents/' -CharacterEncoding 'UTF-8' -Confirm:$false

        $script:request.CHARACTERENCODING | Should -Be 0
    }

    It 'rejects a modify call with no changes specified' {
        $result = Set-DMnfsShare -WebSession $script:session -SharePath '/documents/' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Specify at least one of*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects an unknown share path' {
        $result = Set-DMnfsShare -WebSession $script:session -SharePath '/missing/' -Description 'x' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid SharePath*'
    }

    It 'does not modify when WhatIf is specified' {
        $null = Set-DMnfsShare -WebSession $script:session -SharePath '/documents/' -Description 'x' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'Set-DMnfsClient' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMnfsFileClient { @([pscustomobject]@{ Id = 'client-01'; Name = '192.0.2.50' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = [pscustomobject]@{ ACCESSVAL = 1; ALLSQUASH = 1; ROOTSQUASH = 1 } }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'modifies the access permission of a resolved client' {
        $result = Set-DMnfsClient -WebSession $script:session -ClientName '192.0.2.50' -Access ReadOnly -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'NFS_SHARE_AUTH_CLIENT/client-01'
        $script:request.ID | Should -Be 'client-01'
        $script:request.ACCESSVAL | Should -Be 0
        $script:request.vstoreId | Should -Be '7'
    }

    It 'preserves current AllSquash/RootSquash values when not specified' {
        $null = Set-DMnfsClient -WebSession $script:session -ClientName '192.0.2.50' -Access ReadWrite -Confirm:$false

        $script:request.ALLSQUASH | Should -Be 1
        $script:request.ROOTSQUASH | Should -Be 1
    }

    It 'translates explicitly specified AllSquash/RootSquash/AnonymousId to API values' {
        $null = Set-DMnfsClient -WebSession $script:session -ClientName '192.0.2.50' -AllSquash AllSquash -RootSquash NoRootSquash -AnonymousId 65534 -Confirm:$false

        $script:request.ALLSQUASH | Should -Be 0
        $script:request.ROOTSQUASH | Should -Be 1
        $script:request.ANONYMOUSID | Should -Be 65534
    }

    It 'rejects a modify call with no changes specified' {
        $result = Set-DMnfsClient -WebSession $script:session -ClientName '192.0.2.50' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Specify at least one of*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects an unknown client name' {
        $result = Set-DMnfsClient -WebSession $script:session -ClientName 'missing' -Access ReadOnly -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike "*Invalid ClientName*"
    }

    It 'does not modify when WhatIf is specified' {
        $null = Set-DMnfsClient -WebSession $script:session -ClientName '192.0.2.50' -Access ReadOnly -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Method -eq 'PUT' }
    }
}

Describe 'Set-DMCifsShare' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMShare { @([pscustomobject]@{ Id = 'cifs-01'; Name = 'docs' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'modifies the description and access-based enumeration of a resolved share' {
        $result = Set-DMCifsShare -WebSession $script:session -ShareName 'docs' -Description 'Team files' -EnableAccessBasedEnum $true -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'CIFSSHARE/cifs-01'
        $script:request.ID | Should -Be 'cifs-01'
        $script:request.DESCRIPTION | Should -Be 'Team files'
        $script:request.ABEENABLE | Should -BeTrue
        $script:request.vstoreId | Should -Be '7'
    }

    It 'rejects a modify call with no changes specified' {
        $result = Set-DMCifsShare -WebSession $script:session -ShareName 'docs' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Specify at least one of*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects an unknown share name' {
        $result = Set-DMCifsShare -WebSession $script:session -ShareName 'missing' -Description 'x' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid ShareName*'
    }

    It 'does not modify when WhatIf is specified' {
        $null = Set-DMCifsShare -WebSession $script:session -ShareName 'docs' -Description 'x' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
