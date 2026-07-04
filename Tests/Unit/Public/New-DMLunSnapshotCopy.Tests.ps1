BeforeDiscovery {
    $script:newSnapshotCopyModule = New-Module -Name NewDMLunSnapshotCopyTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMLunSnapshot {
            param([pscustomobject]$WebSession, [string]$Name, [string]$Id)
        }

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorLunSnapshot.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMLunSnapshotCopy.ps1"

        Export-ModuleMember -Function New-DMLunSnapshotCopy
    }

    Import-Module $script:newSnapshotCopyModule -Force
}

AfterAll {
    Remove-Module -Name NewDMLunSnapshotCopyTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope NewDMLunSnapshotCopyTestModule {
Describe 'New-DMLunSnapshotCopy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMLunSnapshot {
            $items = @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }
        Mock Invoke-DeviceManager {
            $script:snapshotCopyRequest = $BodyData
            $script:snapshotCopyMethod = $Method
            $script:snapshotCopyResource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data = [pscustomobject]@{
                    ID = 'snap-02'; NAME = $BodyData.NAME; SOURCELUNID = 'lun-01'
                    SOURCELUNNAME = 'data-lun'; HEALTHSTATUS = 1; RUNNINGSTATUS = 43
                    USERCAPACITY = 2097152; CONSUMEDCAPACITY = 0; IOPRIORITY = 1
                    isReadOnly = $false; WWN = 'copy-wwn'
                }
            }
        }
    }

    It 'creates a named snapshot copy from an existing snapshot' {
        $result = New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' -SnapshotCopyName 'patch-copy' -Description 'Copy for testing'

        $result.GetType().Name | Should -Be 'OceanstorLunSnapshot'
        $result.Id | Should -Be 'snap-02'
        $result.Name | Should -Be 'patch-copy'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
        $script:snapshotCopyMethod | Should -Be 'POST'
        $script:snapshotCopyResource | Should -Be 'snapshot/createcopy'
        $script:snapshotCopyRequest.ID | Should -Be 'snap-01'
        $script:snapshotCopyRequest.NAME | Should -Be 'patch-copy'
        $script:snapshotCopyRequest.DESCRIPTION | Should -Be 'Copy for testing'
        Should -Invoke Get-DMLunSnapshot -Times 2 -Exactly -ParameterFilter { $Name -eq 'before-patch' -and -not $Id }
        Should -Invoke Get-DMLunSnapshot -Times 0 -Exactly -ParameterFilter { -not $Name -and -not $Id }
    }

    It 'creates a default copy name from the original snapshot name' {
        $result = New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch'

        $result.Name | Should -Be 'copy_before-patch'
        $script:snapshotCopyRequest.NAME | Should -Be 'copy_before-patch'
        $script:snapshotCopyRequest.ID | Should -Be 'snap-01'
    }

    It 'rejects a source snapshot name that does not exist' {
        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'missing' } |
            Should -Throw '*Invalid SourceSnapShotName*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a source snapshot name that is not unique' {
        Mock Get-DMLunSnapshot {
            $items = @(
                [pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }
                [pscustomobject]@{ Id = 'snap-02'; Name = 'before-patch' }
            )
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }

        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' } |
            Should -Throw '*SourceSnapShotName is ambiguous*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects copy names that contain unsupported characters' {
        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' -SnapshotCopyName 'bad copy name' } |
            Should -Throw

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'requires an explicit copy name when the generated name exceeds the API limit' {
        $longName = 'a' * 252
        Mock Get-DMLunSnapshot {
            $items = @([pscustomobject]@{ Id = 'snap-long'; Name = $longName })
            if ($Id) { return @($items | Where-Object Id -EQ $Id) }
            if ($Name) { return @($items | Where-Object Name -EQ $Name) }
            return $items
        }

        $result = New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName $longName -ErrorAction SilentlyContinue -ErrorVariable copyErrors

        $result | Should -BeNullOrEmpty
        ($copyErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*generated SnapshotCopyName exceeds*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'creates a snapshot copy from a source snapshot identified by Id' {
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            if ($Id -eq 'snap-01') { return @([pscustomobject]@{ Id = 'snap-01'; Name = 'before-patch' }) }
            @()
        }

        $result = New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotId 'snap-01' -SnapshotCopyName 'patch-copy'

        $result.Id | Should -Be 'snap-02'
        $script:snapshotCopyRequest.ID | Should -Be 'snap-01'
    }

    It 'rejects a source snapshot Id that does not exist' {
        Mock Get-DMLunSnapshot {
            param($WebSession, $Id)
            @()
        }

        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotId 'missing' } |
            Should -Throw '*Invalid SourceSnapShotId*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects supplying both SourceSnapShotName and SourceSnapShotId' {
        { New-DMLunSnapshotCopy -WebSession $script:session -SourceSnapShotName 'before-patch' -SourceSnapShotId 'snap-01' } |
            Should -Throw '*parameter set*'
    }

    It 'accepts a source snapshot from the pipeline by property Id' {
        $piped = [pscustomobject]@{ Id = 'snap-01' }

        $result = $piped | New-DMLunSnapshotCopy -WebSession $script:session

        $result.Id | Should -Be 'snap-02'
        $script:snapshotCopyRequest.ID | Should -Be 'snap-01'
    }
}
}
