BeforeDiscovery {
    $script:getDisksModule = New-Module -Name GetDisksTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMparsedElabel.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Set-DMHostInitiator.ps1"

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Private" -Filter 'class-*.ps1' |
            Where-Object Name -ne 'class-OceanStorMappingView.ps1' |
            ForEach-Object { . $_.FullName }

        Get-ChildItem -LiteralPath "$testRoot\..\..\..\POSH-Oceanstor\Public" -Filter 'Get-*.ps1' |
            ForEach-Object { . $_.FullName }

        Export-ModuleMember -Function 'Get-*'
    }

    Import-Module $script:getDisksModule -Force
}

AfterAll {
    Remove-Module -Name GetDisksTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope GetDisksTestModule {
Describe 'Public getter functions' {
    BeforeAll {
        $script:eLabel = @(
            'BoardType=board-01'
            'BarCode=serial-01'
            'Item=part-01'
            'Description=component'
            'Manufactured=2026-01-01'
            'VendorName=Huawei'
        ) -join "`n"

        function script:New-TestDisk {
            param(
                [string]$Id = 'disk-01',
                [string]$Location = 'DAE000.1',
                [string]$PoolId = 'pool-01',
                [string]$PoolName = 'performance',
                [string]$LogicType = '1',
                [string]$IsCofferDisk = 'FALSE'
            )

            [pscustomobject]@{
                ID = $Id; LOCATION = $Location; POOLID = $PoolId; POOLNAME = $PoolName
                LOGICTYPE = $LogicType; ISCOFFERDISK = $IsCofferDisk; barcode = '00PARTNUM01'
                ELABEL = $script:eLabel; HEALTHSTATUS = 1; RUNNINGSTATUS = 27
                TYPE = 10; DISKTYPE = 14; DISKFORM = 3; manuCapacity = 1GB
            }
        }
    }
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
        Mock Invoke-DeviceManager { [pscustomobject]@{ data = @() } }
    }
    Describe 'Disk getter functions' {
        BeforeEach {
            Mock Invoke-DeviceManager {
                [pscustomobject]@{ data = @(
                    (New-TestDisk -Id 'disk-free' -Location 'DAE000.1' -PoolId 'pool-01' -PoolName 'performance')
                    (New-TestDisk -Id 'disk-coffer' -Location 'DAE001.2' -PoolId 'pool-02' -PoolName 'capacity' -LogicType '2' -IsCofferDisk 'TRUE')
                ) }
            }
        }

        It 'gets all disks' {
            $result = @(Get-DMdisk -WebSession $script:session)

            $result.Count | Should -Be 2
            $result[0].PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
            $result[0].'Part Number' | Should -Be 'part-01'
        }

        It 'gets disks by location' {
            $result = (Get-DMDiskbyLocation -WebSession $script:session -Location 'DAE001')[0]

            $result.id | Should -Be 'disk-coffer'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets disks by pool id' {
            $result = (Get-DMdiskbyPoolId -WebSession $script:session -PoolId 'pool-01')[0]

            $result.id | Should -Be 'disk-free'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets disks by pool name' {
            $result = (Get-DMdiskbyPoolName -WebSession $script:session -PoolName 'capacity')[0]

            $result.id | Should -Be 'disk-coffer'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets coffer disks' {
            $result = (Get-DMcofferDisk -WebSession $script:session)[0]

            $result.id | Should -Be 'disk-coffer'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }

        It 'gets free disks' {
            $result = (Get-DMfreeDisk -WebSession $script:session)[0]

            $result.id | Should -Be 'disk-free'
            $result.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames |
                Should -Be @('Id', 'Location', 'Health Status', 'Disk Usage', 'PoolName')
        }
    }
}
}
