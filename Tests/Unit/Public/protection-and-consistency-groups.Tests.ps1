BeforeDiscovery {
    $script:protectionModule = New-Module -Name ProtectionGroupTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlunGroup { param([pscustomobject]$WebSession) }
        function Get-DMvStore { param([pscustomobject]$WebSession) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMProtectionGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMSnapshotConsistencyGroupCopy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Enable-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restart-DMSnapshotConsistencyGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Restore-DMSnapshotConsistencyGroup.ps1"

        Export-ModuleMember -Function '*-DMProtectionGroup', '*-DMSnapshotConsistencyGroup', '*-DMSnapshotConsistencyGroupCopy'
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
