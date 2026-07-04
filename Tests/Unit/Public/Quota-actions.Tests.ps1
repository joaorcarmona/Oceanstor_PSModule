BeforeDiscovery {
    $script:quotaModule = New-Module -Name QuotaActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMFileSystem { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\ConvertTo-DMQuotaByte.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorQuota.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMQuota.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMQuota.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMQuota.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMQuota.ps1"

        Export-ModuleMember -Function 'Get-DMQuota', 'New-DMQuota', 'Set-DMQuota', 'Remove-DMQuota'
    }
    Import-Module $script:quotaModule -Force
}

AfterAll {
    Remove-Module -Name QuotaActionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope QuotaActionsTestModule {
Describe 'Get-DMQuota' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
    }

    It 'fetches a single quota directly by composite Id' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{ ID = '34@4@1'; PARENTTYPE = '40'; PARENTID = 'fs-01'; QUOTATYPE = '1'; SPACEHARDQUOTA = 10737418240 }
            }
        }

        $result = Get-DMQuota -WebSession $script:session -Id '34@4@1'

        $result.GetType().Name | Should -Be 'OceanstorQuota'
        $result.Id | Should -Be '34@4@1'
        $result.'Parent Type' | Should -Be 'FileSystem'
        $result.'Space Hard Quota' | Should -Be 10737418240
        $script:resource | Should -Be 'FS_QUOTA/34%404%401'
    }

    It 'scopes the query to a resolved file system' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @() }
        }

        $null = Get-DMQuota -WebSession $script:session -FileSystemName 'documents'

        $script:resource | Should -BeLike 'FS_QUOTA?PARENTTYPE=40&PARENTID=fs-01*'
    }

    It 'rejects an unknown file system name' {
        { Get-DMQuota -WebSession $script:session -FileSystemName 'missing' -ErrorAction Stop } |
            Should -Throw '*Invalid FileSystemName*'
    }

    It 'filters returned quotas client-side by QuotaType' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{
                data = @(
                    [pscustomobject]@{ ID = '1'; PARENTTYPE = '40'; PARENTID = 'fs-01'; QUOTATYPE = '1' }
                    [pscustomobject]@{ ID = '2'; PARENTTYPE = '40'; PARENTID = 'fs-01'; QUOTATYPE = '2'; USRGRPOWNERNAME = 'jdoe' }
                )
            }
        }

        $result = @(Get-DMQuota -WebSession $script:session -FileSystemName 'documents' -QuotaType User)

        $result.Count | Should -Be 1
        $result[0].'Account Name' | Should -Be 'jdoe'
    }
}

Describe 'New-DMQuota' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{ ID = 'fs-01@4@1'; PARENTTYPE = $BodyData.PARENTTYPE; PARENTID = $BodyData.PARENTID; QUOTATYPE = $BodyData.QUOTATYPE; SPACEHARDQUOTA = $BodyData.SPACEHARDQUOTA }
            }
        }
    }

    It 'creates a directory quota on a file system with a converted byte limit' {
        $result = New-DMQuota -WebSession $script:session -FileSystemName 'documents' -SpaceHardLimit '10GB'

        $result.GetType().Name | Should -Be 'OceanstorQuota'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'FS_QUOTA'
        $script:request.PARENTTYPE | Should -Be 40
        $script:request.PARENTID | Should -Be 'fs-01'
        $script:request.QUOTATYPE | Should -Be 1
        $script:request.SPACEHARDQUOTA | Should -Be 10737418240
    }

    It 'creates a quota on a resolved dTree' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'fs-01@4'; NAME = 'archive' }) }
            }
            return [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{ ID = 'fs-01@4@1'; PARENTTYPE = $BodyData.PARENTTYPE; PARENTID = $BodyData.PARENTID }
            }
        }

        $null = New-DMQuota -WebSession $script:session -FileSystemName 'documents' -DtreeName 'archive' -SpaceHardLimit '10GB'

        $script:request.PARENTTYPE | Should -Be 16445
        $script:request.PARENTID | Should -Be 'fs-01@4'
    }

    It 'creates a user quota with AccountName/AccountType' {
        $null = New-DMQuota -WebSession $script:session -FileSystemName 'documents' -QuotaType User -AccountName 'jdoe' -AccountType Local -SpaceHardLimit '5GB'

        $script:request.QUOTATYPE | Should -Be 2
        $script:request.USRGRPOWNERNAME | Should -Be 'jdoe'
        $script:request.USRGRPTYPE | Should -Be 1
    }

    It 'rejects a create call with no limit specified' {
        { New-DMQuota -WebSession $script:session -FileSystemName 'documents' -ErrorAction Stop } |
            Should -Throw '*Specify at least one of*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a User quota without AccountName/AccountType' {
        { New-DMQuota -WebSession $script:session -FileSystemName 'documents' -QuotaType User -SpaceHardLimit '5GB' -ErrorAction Stop } |
            Should -Throw '*AccountName and AccountType are mandatory*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a hard limit that does not exceed the soft limit' {
        $result = New-DMQuota -WebSession $script:session -FileSystemName 'documents' -SpaceSoftLimit '10GB' -SpaceHardLimit '10GB' -ErrorAction SilentlyContinue -ErrorVariable createErrors

        $result | Should -BeNullOrEmpty
        ($createErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*SpaceHardLimit must be greater than SpaceSoftLimit*'
    }

    It 'does not create when WhatIf is specified' {
        $null = New-DMQuota -WebSession $script:session -FileSystemName 'documents' -SpaceHardLimit '10GB' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'Set-DMQuota' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'modifies the space hard limit of a quota with a converted byte value' {
        $result = Set-DMQuota -WebSession $script:session -Id '34@4@1' -SpaceHardLimit '20GB' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'FS_QUOTA/34%404%401'
        $script:request.ID | Should -Be '34@4@1'
        $script:request.SPACEHARDQUOTA | Should -Be 21474836480
    }

    It 'rejects a modify call with no limit specified' {
        { Set-DMQuota -WebSession $script:session -Id '34@4@1' -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*Specify at least one of*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a hard limit that does not exceed the soft limit' {
        $result = Set-DMQuota -WebSession $script:session -Id '34@4@1' -SpaceSoftLimit '10GB' -SpaceHardLimit '10GB' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable setErrors

        $result | Should -BeNullOrEmpty
        ($setErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*SpaceHardLimit must be greater than SpaceSoftLimit*'
    }

    It 'does not modify when WhatIf is specified' {
        $null = Set-DMQuota -WebSession $script:session -Id '34@4@1' -SpaceHardLimit '20GB' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'modifies every quota piped in, not just the last one' {
        $items = @([pscustomobject]@{ Id = '1@4@1' }, [pscustomobject]@{ Id = '2@4@1' })
        $null = $items | Set-DMQuota -WebSession $script:session -SpaceHardLimit '20GB' -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'FS_QUOTA/1%404%401' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'FS_QUOTA/2%404%401' }
    }
}

Describe 'Remove-DMQuota' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'removes a quota by composite Id' {
        $result = Remove-DMQuota -WebSession $script:session -Id '34@4@1' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'FS_QUOTA/34%404%401'
    }

    It 'does not remove when WhatIf is specified' {
        $null = Remove-DMQuota -WebSession $script:session -Id '34@4@1' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'removes every quota piped in, not just the last one' {
        $items = @([pscustomobject]@{ Id = '1@4@1' }, [pscustomobject]@{ Id = '2@4@1' })
        $null = $items | Remove-DMQuota -WebSession $script:session -Confirm:$false

        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'FS_QUOTA/1%404%401' }
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly -ParameterFilter { $Resource -eq 'FS_QUOTA/2%404%401' }
    }
}
}
