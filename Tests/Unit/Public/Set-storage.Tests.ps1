BeforeDiscovery {
    $script:setStorageModule = New-Module -Name SetStorageTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMluns {
            param([pscustomobject]$WebSession)
        }

        function Get-DMFileSystem {
            param([pscustomobject]$WebSession)
        }

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\ConvertTo-DMCapacityBlocks.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMLun.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMFileSystem.ps1"

        Export-ModuleMember -Function Set-DMLun, Set-DMFileSystem
    }

    Import-Module $script:setStorageModule -Force
}

AfterAll {
    Remove-Module -Name SetStorageTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope SetStorageTestModule {
Describe 'Set-DMLun' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMluns {
            @(
                [pscustomobject]@{
                    Id = 'lun-01'; Name = 'database'; RealCapacity = 2097152
                    'Lun Size' = 1; 'Sector Size' = 512
                },
                [pscustomobject]@{
                    Id = 'lun-02'; Name = 'archive'; RealCapacity = 4194304
                    'Lun Size' = 2; 'Sector Size' = 512
                }
            )
        }
        $script:requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $script:requests.Add([pscustomobject]@{
                Method = $Method
                Resource = $Resource
                Body = $BodyData
            })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'renames a V6 LUN through its resource' {
        $result = Set-DMLun -WebSession $script:session -LunName 'database' -NewName 'database-prod' -Confirm:$false

        $result.Code | Should -Be 0
        $script:requests.Count | Should -Be 1
        $script:requests[0].Method | Should -Be 'PUT'
        $script:requests[0].Resource | Should -Be 'lun/lun-01'
        $script:requests[0].Body.ID | Should -Be 'lun-01'
        $script:requests[0].Body.NAME | Should -Be 'database-prod'
    }

    It 'expands a V6 LUN through the dedicated action' {
        $null = Set-DMLun -WebSession $script:session -LunName 'database' -Capacity '2GB' -Confirm:$false

        $script:requests.Count | Should -Be 1
        $script:requests[0].Resource | Should -Be 'lun/expand'
        $script:requests[0].Body.ID | Should -Be 'lun-01'
        $script:requests[0].Body.CAPACITY | Should -Be 4194304
    }

    It 'modifies properties before expanding when both are requested' {
        $null = Set-DMLun -WebSession $script:session -LunName 'database' -NewName 'database-prod' `
            -Capacity '2,5GB' -ApiProperties @{ IOPRIORITY = 3 } -Confirm:$false

        $script:requests.Count | Should -Be 2
        $script:requests[0].Resource | Should -Be 'lun/lun-01'
        $script:requests[0].Body.IOPRIORITY | Should -Be 3
        $script:requests[1].Resource | Should -Be 'lun/expand'
        $script:requests[1].Body.CAPACITY | Should -Be 5242880
    }

    It 'rejects LUN reduction' {
        { Set-DMLun -WebSession $script:session -LunName 'database' -Capacity '512MB' -Confirm:$false } |
            Should -Throw '*only be expanded*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects non-V6 sessions' {
        $v3Session = [pscustomobject]@{ version = 'V300R006' }

        { Set-DMLun -WebSession $v3Session -LunName 'database' -NewName 'database-prod' -Confirm:$false } |
            Should -Throw '*only OceanStor Dorado V6*'

        Should -Invoke Get-DMluns -Times 0 -Exactly
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects reserved raw API fields' {
        { Set-DMLun -WebSession $script:session -LunName 'database' -ApiProperties @{ CAPACITY = 4194304 } -Confirm:$false } |
            Should -Throw '*reserved*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not modify a LUN under WhatIf' {
        $null = Set-DMLun -WebSession $script:session -LunName 'database' -NewName 'database-prod' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'Set-DMFileSystem' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMFileSystem {
            @(
                [pscustomobject]@{ Id = 'fs-01'; Name = 'documents'; RealCapacity = 8388608 },
                [pscustomobject]@{ Id = 'fs-02'; Name = 'archive'; RealCapacity = 4194304 }
            )
        }
        $script:requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $script:requests.Add([pscustomobject]@{
                Method = $Method
                Resource = $Resource
                Body = $BodyData
            })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'renames and resizes a file system in one request' {
        $result = Set-DMFileSystem -WebSession $script:session -FileSystemName 'documents' `
            -NewName 'documents-prod' -Capacity '10GB' -Confirm:$false

        $result.Code | Should -Be 0
        $script:requests.Count | Should -Be 1
        $script:requests[0].Method | Should -Be 'PUT'
        $script:requests[0].Resource | Should -Be 'filesystem/fs-01'
        $script:requests[0].Body.ID | Should -Be 'fs-01'
        $script:requests[0].Body.NAME | Should -Be 'documents-prod'
        $script:requests[0].Body.CAPACITY | Should -Be 20971520
    }

    It 'allows a file-system reduction for array-side validation' {
        $null = Set-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -Capacity '2GB' -Confirm:$false

        $script:requests[0].Body.CAPACITY | Should -Be 4194304
    }

    It 'passes additional file-system API fields unchanged' {
        $null = Set-DMFileSystem -WebSession $script:session -FileSystemName 'documents' `
            -Description '' -ApiProperties @{ CAPACITYTHRESHOLD = 85; AUTOGROWTHRESHOLDPERCENT = 90 } -Confirm:$false

        $script:requests[0].Body.DESCRIPTION | Should -Be ''
        $script:requests[0].Body.CAPACITYTHRESHOLD | Should -Be 85
        $script:requests[0].Body.AUTOGROWTHRESHOLDPERCENT | Should -Be 90
    }

    It 'rejects an unchanged file-system capacity' {
        { Set-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -Capacity '4GB' -Confirm:$false } |
            Should -Throw '*already the current*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a duplicate new file-system name' {
        { Set-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -NewName 'archive' -Confirm:$false } |
            Should -Throw '*already exists*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not modify a file system under WhatIf' {
        $null = Set-DMFileSystem -WebSession $script:session -FileSystemName 'documents' -NewName 'documents-prod' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
