BeforeAll {
    function global:Get-DMFileSystem {
        param([pscustomobject]$WebSession)
        @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' })
    }
    function global:Remove-DMDTree {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param([pscustomobject]$WebSession, [string]$FileSystemName, [string]$DTreeName)
        $global:DTreeRemovalInvocation = [pscustomobject]@{
            FileSystemName = $FileSystemName; DTreeName = $DTreeName; WebSession = $WebSession
        }
        [pscustomobject]@{ Code = 0 }
    }

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorAlarm.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorDtree.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorStoragePool.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorSystem.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorvStore.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorWorkload.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorQuota.ps1"
}

AfterAll {
    Remove-Item -LiteralPath 'Function:\global:Get-DMFileSystem' -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath 'Function:\global:Remove-DMDTree' -ErrorAction SilentlyContinue
    Remove-Variable -Name DTreeRemovalInvocation -Scope Global -ErrorAction SilentlyContinue
}

Describe 'Core model classes' {
    BeforeAll {
        $script:session = [pscustomobject]@{ Name = 'Test-session' }
    }

    It 'maps alarm state and severity' {
        $source = [pscustomobject]@{
            name = 'Controller warning'; alarmStatus = 1; level = 5; type = 1; eventType = 1
            clearName = ''; clearTime = 0; recoverTime = 0; startTime = 0
        }

        $result = New-Object -TypeName OceanStorAlarm -ArgumentList @($source, $script:session)

        $result.Name | Should -Be 'Controller warning'
        $result.'Alarm Status' | Should -Be 'unrecovered'
        $result.Level | Should -Be 'major'
        $result.Session | Should -Be $script:session
    }

    It 'leaves epoch time properties null when the source value is zero' {
        $source = [pscustomobject]@{
            name = 'Idle event'; alarmStatus = 1; level = 3; type = 1; eventType = 1
            clearName = ''; clearTime = 0; recoverTime = 0; startTime = 0
        }

        $result = New-Object -TypeName OceanStorAlarm -ArgumentList @($source, $script:session)

        $result.'Start time' | Should -BeNullOrEmpty
        $result.'Cleared Time' | Should -BeNullOrEmpty
        $result.'Recover Time' | Should -BeNullOrEmpty
    }

    It 'converts epoch seconds to DateTime and maps the clearing user' {
        # 1704067200 = 2024-01-01T00:00:00Z, 1704153600 = 2024-01-02Z, 1704240000 = 2024-01-03Z
        $source = [pscustomobject]@{
            name = 'Recovered alarm'; alarmStatus = 2; level = 3; type = 1; eventType = 1
            clearName = 'admin'; startTime = 1704067200; clearTime = 1704153600; recoverTime = 1704240000
        }

        $result = New-Object -TypeName OceanStorAlarm -ArgumentList @($source, $script:session)

        $result.'Cleared By' | Should -Be 'admin'
        $result.'Start time' | Should -BeOfType ([datetime])
        $result.'Cleared Time' | Should -BeOfType ([datetime])
        $result.'Recover Time' | Should -BeOfType ([datetime])
        # Compare in UTC so the assertion is independent of the host time zone.
        $result.'Start time'.ToUniversalTime()   | Should -Be ([datetime]'2024-01-01T00:00:00Z').ToUniversalTime()
        $result.'Cleared Time'.ToUniversalTime()  | Should -Be ([datetime]'2024-01-02T00:00:00Z').ToUniversalTime()
        $result.'Recover Time'.ToUniversalTime()  | Should -Be ([datetime]'2024-01-03T00:00:00Z').ToUniversalTime()
    }

    It 'creates a dtree model instance' {
        $result = New-Object -TypeName OceanStorDtree -ArgumentList @([pscustomobject]@{ ID = 'dtree-01' }, $script:session)

        $result.GetType().Name | Should -Be 'OceanStorDtree'
    }

    It 'deletes a dtree through Remove-DMDTree resolving the parent file system by ID' {
        $source = [pscustomobject]@{ ID = 'dtree-01'; NAME = 'project-a'; PARENTID = 'fs-01' }
        $dtree = New-Object -TypeName OceanStorDtree -ArgumentList @($source, $script:session)

        $dtree.Delete().Code | Should -Be 0
        $global:DTreeRemovalInvocation.FileSystemName | Should -Be 'documents'
        $global:DTreeRemovalInvocation.DTreeName | Should -Be 'project-a'
        $global:DTreeRemovalInvocation.WebSession | Should -Be $script:session
    }

    It 'maps storage pool status and converts capacity to GB' {
        $source = [pscustomobject]@{
            ID = 'pool-01'; NAME = 'performance'; HEALTHSTATUS = 1; RUNNINGSTATUS = 27
            DATASPACE = 2097152; USERTOTALCAPACITY = 4194304; NEWUSAGETYPE = 1
        }

        $result = New-Object -TypeName OceanStorStoragePool -ArgumentList @($source, $script:session)

        $result.id | Should -Be 'pool-01'
        $result.'Health Status' | Should -Be 'Normal'
        # sectors * 512 / 1GB: 2097152 -> 1 GB, 4194304 -> 2 GB
        # (the previous class divided by the sector size, collapsing every capacity to ~0)
        $result.'Available For LUN (GB)' | Should -Be 1
        $result.'Total Capacity (GB)' | Should -Be 2
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
            ID = 7; NAME = 'tenant-a'; RUNNINGSTATUS = 1; sanCapacityQuota = 2097152
            sanFreeCapacityQuota = -1; sanTotalCapacity = 2097152; nasCapacityQuota = 2097152
            nasFreeCapacityQuota = -1; nasTotalCapacity = 2097152
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

    It 'maps unconfigured quota dimensions (INVALID_VALUE64) to $null instead of throwing' {
        $source = [pscustomobject]@{
            ID             = 'quota-01'; PARENTTYPE = 16445; PARENTID = 'dtree-01'; QUOTATYPE = 1
            SPACESOFTQUOTA = '-1'                    # sentinel rendered as signed -1
            SPACEHARDQUOTA = '10737418240'           # 10 GB configured
            SPACEUSED      = '0'
            FILESOFTQUOTA  = '18446744073709551615'  # sentinel rendered as unsigned 0xFFFFFFFFFFFFFFFF
            FILEHARDQUOTA  = -1                       # sentinel as a native integer
            FILEUSED       = '0'
        }

        { New-Object -TypeName OceanstorQuota -ArgumentList @($source, $script:session) } | Should -Not -Throw

        $result = New-Object -TypeName OceanstorQuota -ArgumentList @($source, $script:session)
        $result.'Space Soft Quota' | Should -BeNullOrEmpty
        $result.'File Soft Quota' | Should -BeNullOrEmpty
        $result.'File Hard Quota' | Should -BeNullOrEmpty
        $result.'Space Hard Quota' | Should -Be 10737418240
        $result.'Space Used' | Should -Be 0
    }
}
