BeforeAll {
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorAlarm.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorDtree.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorStoragePool.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorSystem.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorvStore.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorWorkload.ps1"
}

Describe 'Core model classes' {
    BeforeAll {
        $script:session = [pscustomobject]@{ Name = 'test-session' }
    }

    It 'maps alarm state and severity' {
        $source = [pscustomobject]@{
            name = 'Controller warning'; alarmStatus = 1; level = 3; type = 1; eventType = 1
            clearTime = 0; recoverTime = 0; startTime = 0
        }

        $result = New-Object -TypeName OceanStorAlarm -ArgumentList @($source, $script:session)

        $result.Name | Should -Be 'Controller warning'
        $result.'Alarm Status' | Should -Be 'unrecovered'
        $result.Level | Should -Be 'major'
        $result.Session | Should -Be $script:session
    }

    It 'creates a dtree model instance' {
        $result = New-Object -TypeName OceanStorDtree -ArgumentList @([pscustomobject]@{ ID = 'dtree-01' }, $script:session)

        $result.GetType().Name | Should -Be 'OceanStorDtree'
    }

    It 'maps storage pool status and converts capacity to GB' {
        $source = [pscustomobject]@{
            ID = 'pool-01'; NAME = 'performance'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27
            DATASPACE = (512 * 1GB); USERTOTALCAPACITY = (512 * 2GB); USAGETYPE = 1
        }

        $result = New-Object -TypeName OceanStorStoragePool -ArgumentList @($source, $script:session)

        $result.id | Should -Be 'pool-01'
        $result.'Health Status' | Should -Be 'Normal'
        $result.dataspace | Should -Be 1
        $result.usertotalcapacity | Should -Be 2
    }

    It 'maps system key-value data' {
        $source = @('ID=system-01', 'PRODUCTVERSION=V600R001', 'wwn=wwn-01', 'HEALTHSTATUS=1', 'RUNNINGSTATUS=1', 'HOTSPAREDISKSCAPACITY=2')

        $result = New-Object -TypeName OceanStorSystem -ArgumentList @($source, $script:session)

        $result.sn | Should -Be 'system-01'
        $result.version | Should -Be 'V600R001'
        $result.'Health Status' | Should -Be 'Normal'
    }

    It 'maps vStore identity and running status' {
        $source = [pscustomobject]@{
            ID = 7; NAME = 'tenant-a'; RUNNINGSTATUS = 1; sanCapacityQuata = 2097152
            sanFreeCapacityQuata = -1; sanTotalCapacity = 2097152; nasCapacityQuata = 2097152
            nasFreeCapacityQuata = -1; nasTotalCapacity = 2097152
        }

        $result = New-Object -TypeName OceanStorvStore -ArgumentList @($source, $script:session)

        $result.ID | Should -Be 7
        $result.Name | Should -Be 'tenant-a'
        $result.'Running Status' | Should -Be 'Online'
    }

    It 'maps workload identity and policy values' {
        $source = [pscustomobject]@{
            ID = 'workload-01'; NAME = 'database'; CREATETYPE = 1; BLOCKSIZE = 2
            ENABLECOMPRESS = $true; ENABLEDEDUP = $false; templateType = 0; distAlg = 0
        }

        $result = New-Object -TypeName OceanStorWorkload -ArgumentList @($source, $script:session)

        $result.Id | Should -Be 'workload-01'
        $result.Name | Should -Be 'database'
        $result.'Block Size' | Should -Be '16 KB'
    }
}
