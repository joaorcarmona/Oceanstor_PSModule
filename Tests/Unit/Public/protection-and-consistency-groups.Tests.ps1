BeforeDiscovery {
    $script:protectionModule = New-Module -Name ProtectionGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlunGroup { param([pscustomobject]$WebSession, [string]$Name, [string]$Id) }
        function Get-DMlun { param([pscustomobject]$WebSession, [string]$Id, [string]$Name) }
        function Get-DMvStore { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [object]$BodyData,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunv6.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorLunGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\New-DMNamedObjectUpdate.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMLunToProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunFromProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Rename-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMSnapshotConsistencyGroupCopy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restart-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restore-DMSnapshotConsistencyGroup.ps1"

        Export-ModuleMember -Function '*-DMProtectionGroup', '*-DMSnapshotConsistencyGroup', '*-DMSnapshotConsistencyGroupCopy', 'Add-DMLunToProtectionGroup', 'Remove-DMLunFromProtectionGroup'
    }

    Import-Module $script:protectionModule -Force
}

AfterAll {
    Remove-Module -Name ProtectionGroupTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope ProtectionGroupTestModule {
Describe 'Protection group commands and class' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlunGroup { @([pscustomobject]@{ Id = '12'; Name = 'production-luns' }) }
        Mock Get-DMvStore { @([pscustomobject]@{ Id = '7'; Name = 'tenant-a' }) }
    }

    It 'creates a protection group from resolved LUN group and vStore names' {
        Mock Invoke-DeviceManager {
            $script:request = $BodyData
            $script:method = $Method
            $script:resource = $Resource
            $script:apiV2 = $ApiV2.IsPresent
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{
                protectGroupId = '3'; protectGroupName = 'pg-db'; lunGroupId = '12'; lunGroupName = 'production-luns'
                lunNum = '2'; snapshotGroupNum = '0'; usageType = '0'; vstoreId = '7'; vstoreName = 'tenant-a'
            } }
        }

        $result = New-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -LunGroupName 'production-luns' -Vstore 'tenant-a' -Description 'database'

        $result.GetType().Name | Should -Be 'OceanstorProtectionGroup'
        $result.Name | Should -Be 'pg-db'
        $result.'Lun Group Id' | Should -Be '12'
        $script:apiV2 | Should -BeTrue
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'protectgroup'
        $script:request.protectGroupName | Should -Be 'pg-db'
        $script:request.lunGroupId | Should -Be '12'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'rejects a protection group with a missing LUN group name' {
        { New-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -LunGroupName 'missing' } |
            Should -Throw '*Invalid LunGroupName*'
    }

    It 'creates a protection group without a LUN group when neither LunGroupName nor LunGroupId is supplied' {
        Mock Invoke-DeviceManager {
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{
                protectGroupId = '3'; protectGroupName = 'pg-empty'; lunGroupId = '-1'
            } }
        }

        $result = New-DMProtectionGroup -WebSession $script:session -Name 'pg-empty'

        $result.Name | Should -Be 'pg-empty'
        $script:request.ContainsKey('lunGroupId') | Should -BeFalse
    }

    It 'creates a protection group using a LunGroupId' {
        Mock Invoke-DeviceManager {
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{
                protectGroupId = '3'; protectGroupName = 'pg-db'; lunGroupId = '12'
            } }
        }

        $result = New-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -LunGroupId '12'

        $result.'Lun Group Id' | Should -Be '12'
        $script:request.lunGroupId | Should -Be '12'
    }

    It 'rejects supplying both LunGroupName and LunGroupId' {
        { New-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -LunGroupName 'production-luns' -LunGroupId '12' } |
            Should -Throw '*parameter set*'
    }

    It 'retrieves protection groups as objects through API v2' {
        Mock Invoke-DeviceManager {
            $script:apiV2 = $ApiV2.IsPresent
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db'; lunGroupId = '12' }) }
        }

        $result = Get-DMProtectionGroup -WebSession $script:session

        $result[0].GetType().Name | Should -Be 'OceanstorProtectionGroup'
        $result[0].Id | Should -Be '3'
        $script:apiV2 | Should -BeTrue
    }

    It 'gets a protection group by Id using an exact server-side filter' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:idResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db'; lunGroupId = '12' }) }
        }

        $result = @(Get-DMProtectionGroup -WebSession $script:session -Id '3')

        $result.Count | Should -Be 1
        $result[0].Id | Should -Be '3'
        $script:idResource | Should -BeLike 'protectgroup?filter=protectGroupId::3*'
    }

    It 'rejects supplying both Name and Id for Get-DMProtectionGroup' {
        { Get-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -Id '3' } | Should -Throw '*parameter set*'
    }

    It 'gets protection groups associated with a LUN by LunName' {
        Mock Get-DMlun {
            $items = @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:assocResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }) }
        }

        $result = @(Get-DMProtectionGroup -WebSession $script:session -LunName 'data-lun')

        $result.Count | Should -Be 1
        $script:assocResource | Should -BeLike 'protectgroup/associate?ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=lun-01*'
    }

    It 'gets protection groups associated with a LUN by LunId' {
        Mock Get-DMlun {
            $items = @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:assocResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }) }
        }

        $result = @(Get-DMProtectionGroup -WebSession $script:session -LunId 'lun-01')

        $result.Count | Should -Be 1
        $script:assocResource | Should -BeLike 'protectgroup/associate?ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=lun-01*'
    }

    It 'gets protection groups associated with a LUN group by LunGroupName' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:assocResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }) }
        }

        $result = @(Get-DMProtectionGroup -WebSession $script:session -LunGroupName 'production-luns')

        $result.Count | Should -Be 1
        $script:assocResource | Should -BeLike 'protectgroup/associate?ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=12*'
    }

    It 'gets protection groups associated with a LUN group by LunGroupId' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:assocResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }) }
        }

        $result = @(Get-DMProtectionGroup -WebSession $script:session -LunGroupId '12')

        $result.Count | Should -Be 1
        $script:assocResource | Should -BeLike 'protectgroup/associate?ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=12*'
    }

    It 'gets protection groups associated with a piped LUN object' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:assocResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }) }
        }
        $lun = [OceanstorLunv6]::new([pscustomobject]@{ ID = 'lun-01'; NAME = 'data-lun'; TYPE = 11; SECTORSIZE = 512 }, $script:session)

        $result = @($lun | Get-DMProtectionGroup -WebSession $script:session)

        $result.Count | Should -Be 1
        $script:assocResource | Should -BeLike 'protectgroup/associate?ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=lun-01*'
    }

    It 'gets protection groups associated with a piped LUN group object' {
        Mock Invoke-DeviceManager {
            param($WebSession, $Method, $Resource, $BodyData, $ApiV2)
            $script:assocResource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }) }
        }
        $lunGroup = [OceanStorLunGroup]::new([pscustomobject]@{ ID = '12'; NAME = 'production-luns'; GROUPTYPE = 0 }, $script:session)

        $result = @($lunGroup | Get-DMProtectionGroup -WebSession $script:session)

        $result.Count | Should -Be 1
        $script:assocResource | Should -BeLike 'protectgroup/associate?ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=12*'
    }

    It 'rejects a piped object of an unsupported type' {
        { [pscustomobject]@{ Id = '1' } | Get-DMProtectionGroup -WebSession $script:session } |
            Should -Throw '*Unsupported pipeline object type*'
    }

    It 'removes a protection group using its resolved ID' {
        Mock Get-DMProtectionGroup { @([OceanstorProtectionGroup]::new([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }, $script:session)) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:apiV2 = $ApiV2.IsPresent
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'protectgroup/3'
        $script:apiV2 | Should -BeTrue
    }

    It 'removes every protection group piped in, not just the last one' {
        Mock Get-DMProtectionGroup {
            @(
                [OceanstorProtectionGroup]::new([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-a' }, $script:session)
                [OceanstorProtectionGroup]::new([pscustomobject]@{ protectGroupId = '4'; protectGroupName = 'pg-b' }, $script:session)
            )
        }
        $resources = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-DeviceManager {
            $resources.Add($Resource)
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $items = @([pscustomobject]@{ Name = 'pg-a' }, [pscustomobject]@{ Name = 'pg-b' })
        $null = $items | Remove-DMProtectionGroup -WebSession $script:session -Confirm:$false

        $resources | Should -Contain 'protectgroup/3'
        $resources | Should -Contain 'protectgroup/4'
    }

    It 'removes a protection group by Id' {
        Mock Get-DMProtectionGroup { @([OceanstorProtectionGroup]::new([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db' }, $script:session)) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMProtectionGroup -WebSession $script:session -Id '3' -Confirm:$false

        $result.Code | Should -Be 0
        $script:resource | Should -Be 'protectgroup/3'
    }

    It 'rejects supplying both Name and Id for Remove-DMProtectionGroup' {
        Mock Get-DMProtectionGroup { @([pscustomobject]@{ Id = '3'; Name = 'pg-db' }) }

        { Remove-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -Id '3' -Confirm:$false } |
            Should -Throw '*parameter set*'
    }

    It 'gets the associated LUN group and dispatches deletion from the model' {
        $ConfirmPreference = 'None'
        Mock Invoke-DeviceManager {
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ protectGroupId = '3'; protectGroupName = 'pg-db'; lunGroupId = '12' }) }
            }

            $script:deleteResource = $Resource
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
        $group = [OceanstorProtectionGroup]::new([pscustomobject]@{
            protectGroupId = '3'; protectGroupName = 'pg-db'; lunGroupId = '12'
        }, $script:session)

        $group.GetLunGroup().Name | Should -Be 'production-luns'
        $group.Delete().Code | Should -Be 0
        $script:deleteResource | Should -Be 'protectgroup/3'
    }
}

Describe 'Add-DMLunToProtectionGroup and Remove-DMLunFromProtectionGroup' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMProtectionGroup { @([pscustomobject]@{ Id = '3'; Name = 'pg-db' }) }
        Mock Get-DMlun {
            param($WebSession, $Id, $Name)
            $items = @([pscustomobject]@{ Id = '10'; Name = 'data-lun' })
            if ($Id) {
                if ($Id -in '10', '11', '12') { return @([pscustomobject]@{ Id = $Id; Name = "lun-$Id" }) }
                return @()
            }
            if ($Name) {
                return @($items | Where-Object Name -EQ $Name)
            }
            return $items
        }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            $script:apiV2 = $ApiV2.IsPresent
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = @() }
        }
    }

    It 'adds a single LUN by name using the single-LUN interface' {
        $result = Add-DMLunToProtectionGroup -WebSession $script:session -Name 'pg-db' -LunName 'data-lun'

        $result.Code | Should -Be 0
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'protectgroup/associate'
        $script:apiV2 | Should -BeTrue
        $script:request.protectGroupId | Should -Be '3'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 11
        $script:request.ASSOCIATEOBJID | Should -Be '10'
        Should -Invoke Get-DMlun -Times 2 -Exactly -ParameterFilter { $Name -eq 'data-lun' -and -not $Id }
        Should -Invoke Get-DMlun -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'adds a single LUN by id using the single-LUN interface' {
        $result = Add-DMLunToProtectionGroup -WebSession $script:session -Id '3' -LunId '10'

        $result.Code | Should -Be 0
        $script:resource | Should -Be 'protectgroup/associate'
        $script:request.ASSOCIATEOBJID | Should -Be '10'
    }

    It 'adds multiple LUNs using the batch interface' {
        $result = Add-DMLunToProtectionGroup -WebSession $script:session -Name 'pg-db' -LunId '10,11,12'

        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'protectgroup/associate/batch'
        $script:apiV2 | Should -BeFalse
        $script:request.Count | Should -Be 3
        $script:request[0].ID | Should -Be '3'
        ($script:request.ASSOCIATEOBJID | Sort-Object) | Should -Be @('10', '11', '12')
    }

    It 'accepts a LUN object from the pipeline' {
        $lun = [pscustomobject]@{ Id = '10'; Name = 'data-lun' }

        $result = $lun | Add-DMLunToProtectionGroup -WebSession $script:session -Id '3'

        $result.Code | Should -Be 0
        $script:request.ASSOCIATEOBJID | Should -Be '10'
    }

    It 'rejects supplying both Name and Id for the protection group' {
        { Add-DMLunToProtectionGroup -WebSession $script:session -Name 'pg-db' -Id '3' -LunName 'data-lun' } |
            Should -Throw '*parameter set*'
    }

    It 'rejects supplying both LunName and LunId' {
        { Add-DMLunToProtectionGroup -WebSession $script:session -Name 'pg-db' -LunName 'data-lun' -LunId '10' } |
            Should -Throw '*parameter set*'
    }

    It 'rejects an unknown LunId in the comma-separated list' {
        { Add-DMLunToProtectionGroup -WebSession $script:session -Name 'pg-db' -LunId '10,missing' } |
            Should -Throw "*Invalid LunId 'missing'*"
    }

    It 'removes a single LUN by name using the single-LUN interface with a query string' {
        $result = Remove-DMLunFromProtectionGroup -WebSession $script:session -Name 'pg-db' -LunName 'data-lun' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -BeLike 'protectgroup/associate?protectGroupId=3&ASSOCIATEOBJTYPE=11&ASSOCIATEOBJID=10*'
        $script:apiV2 | Should -BeTrue
        Should -Invoke Get-DMlun -Times 2 -Exactly -ParameterFilter { $Name -eq 'data-lun' -and -not $Id }
        Should -Invoke Get-DMlun -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'removes multiple LUNs using the batch interface' {
        $result = Remove-DMLunFromProtectionGroup -WebSession $script:session -Name 'pg-db' -LunId '10,11' -Confirm:$false

        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'protectgroup/associate/batch'
        $script:apiV2 | Should -BeFalse
        $script:request.Count | Should -Be 2
    }
}

Describe 'Set-DMProtectionGroup and Rename-DMProtectionGroup' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMProtectionGroup { @([pscustomobject]@{ Id = '3'; Name = 'pg-db' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            $script:apiV2 = $ApiV2.IsPresent
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'renames a protection group by Name' {
        $result = Set-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -NewName 'pg-db-2' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'protectgroup/3'
        $script:apiV2 | Should -BeTrue
        $script:request.protectGroupName | Should -Be 'pg-db-2'
    }

    It 'renames a protection group by Id' {
        $result = Set-DMProtectionGroup -WebSession $script:session -Id '3' -NewName 'pg-db-2' -Confirm:$false

        $result.Code | Should -Be 0
        $script:request.protectGroupName | Should -Be 'pg-db-2'
    }

    It 'changes the description of a protection group' {
        $null = Set-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -Description 'Tier 1' -Confirm:$false

        $script:request.description | Should -Be 'Tier 1'
        $script:request.ContainsKey('protectGroupName') | Should -BeFalse
    }

    It 'rejects supplying both Name and Id for Set-DMProtectionGroup' {
        { Set-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -Id '3' -NewName 'pg-db-2' -Confirm:$false } |
            Should -Throw '*parameter set*'
    }

    It 'Rename-DMProtectionGroup forwards to Set-DMProtectionGroup by Name' {
        $result = Rename-DMProtectionGroup -WebSession $script:session -Name 'pg-db' -NewName 'pg-db-2' -Confirm:$false

        $result.Code | Should -Be 0
        $script:request.protectGroupName | Should -Be 'pg-db-2'
    }

    It 'Rename-DMProtectionGroup forwards to Set-DMProtectionGroup by Id' {
        $result = Rename-DMProtectionGroup -WebSession $script:session -Id '3' -NewName 'pg-db-2' -Confirm:$false

        $result.Code | Should -Be 0
        $script:request.protectGroupName | Should -Be 'pg-db-2'
    }
}

Describe 'Snapshot consistency group commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:protection = [OceanstorProtectionGroup]::new([pscustomobject]@{
            protectGroupId = '3'; protectGroupName = 'pg-db'; vstoreId = '7'
        }, $script:session)
        $script:snapshotGroup = [OceanstorSnapshotConsistencyGroup]::new([pscustomobject]@{
            ID = '8'; NAME = 'scg-db'; PARENTID = '3'; PARENTNAME = 'pg-db'; vstoreId = '7'
        }, $script:session)
        Mock Get-DMProtectionGroup { @($script:protection) }
        Mock Get-DMSnapshotConsistencyGroup { @($script:snapshotGroup) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{
                ID = '8'; NAME = 'scg-db'; PARENTID = '3'; PARENTNAME = 'pg-db'; RUNNINGSTATUS = '43'; RESTORESPEED = '2'; vstoreId = '7'
            } }
        }
    }

    It 'creates a snapshot consistency group using the protection group ID' {
        $result = New-DMSnapshotConsistencyGroup -WebSession $script:session -Name 'scg-db' -ProtectionGroupName 'pg-db'

        $result.GetType().Name | Should -Be 'OceanstorSnapshotConsistencyGroup'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'SNAPSHOT_CONSISTENCY_GROUP'
        $script:request.PARENTID | Should -Be '3'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'creates a named copy through the consistency group copy endpoint' {
        $null = New-DMSnapshotConsistencyGroupCopy -WebSession $script:session -SourceName 'scg-db'

        $script:resource | Should -Be 'CONSISTENCY_GROUP/createcopy'
        $script:request.COPYSOURCEID | Should -Be '8'
        $script:request.NAME | Should -Be 'copy_scg-db'
    }

    It '<Command> uses its documented lifecycle endpoint' -TestCases @(
        @{ Command = 'Enable-DMSnapshotConsistencyGroup'; Method = 'POST'; Resource = 'snapshot_consistency_group/activate'; Parameters = @{} }
        @{ Command = 'Restart-DMSnapshotConsistencyGroup'; Method = 'POST'; Resource = 'snapshot_consistency_group/restore'; Parameters = @{} }
        @{ Command = 'Restore-DMSnapshotConsistencyGroup'; Method = 'PUT'; Resource = 'SNAPSHOT_CONSISTENCY_GROUP/rollback'; Parameters = @{ RestoreSpeed = 'High' } }
    ) {
        param($Command, $Method, $Resource, $Parameters)

        $result = & $Command -WebSession $script:session -Name 'scg-db' -Confirm:$false @Parameters

        $result.Code | Should -Be 0
        $script:method | Should -Be $Method
        $script:resource | Should -Be $Resource
        $script:request.ID | Should -Be '8'
        if ($Command -eq 'Restore-DMSnapshotConsistencyGroup') {
            $script:request.RESTORESPEED | Should -Be 3
        }
    }

    It 'removes a snapshot consistency group using its ID' {
        $result = Remove-DMSnapshotConsistencyGroup -WebSession $script:session -Name 'scg-db' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'SNAPSHOT_CONSISTENCY_GROUP/8'
    }
}
}
