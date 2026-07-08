BeforeDiscovery {
    $script:mappingViewModule = New-Module -Name MappingViewTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMhostGroup { param([pscustomobject]$WebSession, [string]$Name, [string]$Id) }
        function Get-DMlunGroup { param([pscustomobject]$WebSession, [string]$Name, [string]$Id) }
        function Get-DMPortGroup { param([pscustomobject]$WebSession) }
        function Get-DMhost { param([pscustomobject]$WebSession, [string]$Name, [string]$Id) }
        function Get-DMlun { param([pscustomobject]$WebSession, [string]$Name, [string]$Id) }
        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMHostGroupToMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMHostGroupFromMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMLunGroupToMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMLunGroupFromMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMPortGroupToMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMPortGroupFromMappingView.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMmapLunToHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMmapLunFromHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMmapLunGroupToHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMmapLunGroupToHostGroup.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMunmapLunGroupFromHost.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMunmapLunGroupFromHostGroup.ps1"

        Export-ModuleMember -Function '*-DMMappingView', '*-DMHostGroupToMappingView', '*-DMHostGroupFromMappingView',
            '*-DMLunGroupToMappingView', '*-DMLunGroupFromMappingView', '*-DMPortGroupToMappingView',
            '*-DMPortGroupFromMappingView', 'Add-DMmapLunToHost', 'Remove-DMmapLunFromHost',
            'Add-DMmapLunGroupToHost', 'Add-DMmapLunGroupToHostGroup', 'Remove-DMunmapLunGroupFromHost',
            'Remove-DMunmapLunGroupFromHostGroup'
    }

    Import-Module $script:mappingViewModule -Force
}

AfterAll {
    Remove-Module -Name MappingViewTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope MappingViewTestModule {
Describe 'Mapping view commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:viewData = [pscustomobject]@{
            ID = 'mv-01'; NAME = 'application'; DESCRIPTION = 'database access'; TYPE = 245
            HEALTHSTATUS = '1'; RUNNINGSTATUS = '27'; HOSTGROUPID = 'hg-01'
            LUNGROUPID = 'lg-01'; PORTGROUPID = 'pg-01'; vstoreId = '7'; vstoreName = 'tenant-a'
        }
        $script:view = [OceanStorMappingView]::new($script:viewData, $script:session)
        Mock Get-DMhostGroup { @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' }) }
        Mock Get-DMlunGroup { @([pscustomobject]@{ Id = 'lg-01'; Name = 'production' }) }
        Mock Get-DMPortGroup { @([pscustomobject]@{ Id = 'pg-01'; Name = 'front-end' }) }
    }

    It 'creates a mapping view and returns a typed object' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = $script:viewData }
        }

        $result = New-DMMappingView -WebSession $script:session -Name 'application' -Description 'database access' -VstoreId '7'

        $result.GetType().Name | Should -Be 'OceanStorMappingView'
        $result.Name | Should -Be 'application'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'mappingview'
        $script:request.TYPE | Should -Be 245
        $script:request.DESCRIPTION | Should -Be 'database access'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'queries associated mapping views for a host group' {
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ data = @($script:viewData) }
        }

        $result = @(Get-DMMappingView -WebSession $script:session -HostGroupName 'cluster01' -VstoreId '7')

        $result[0].GetType().Name | Should -Be 'OceanStorMappingView'
        $script:method | Should -Be 'GET'
        $script:resource | Should -BeLike 'mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=14&ASSOCIATEOBJID=hg-01&vstoreId=7*'
    }

    It 'queries associated mapping views for LUN and port groups with their REST object types' {
        Mock Invoke-DeviceManager {
            $script:resources += $Resource
            [pscustomobject]@{ data = @($script:viewData) }
        }
        $script:resources = @()

        $null = Get-DMMappingView -WebSession $script:session -LunGroupName 'production'
        $null = Get-DMMappingView -WebSession $script:session -PortGroupName 'front-end'

        @($script:resources -like 'mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=256&ASSOCIATEOBJID=lg-01*').Count | Should -BeGreaterThan 0
        @($script:resources -like 'mappingview/associate?TYPE=245&ASSOCIATEOBJTYPE=257&ASSOCIATEOBJID=pg-01*').Count | Should -BeGreaterThan 0
    }

    It 'requests mapping views by Name using a server-side filter hint' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @($script:viewData) }
        }

        $result = @(Get-DMMappingView -WebSession $script:session -Name 'application')

        $result[0].Name | Should -Be 'application'
        $script:resource | Should -BeLike 'mappingview?filter=NAME::application*'
    }

    It 'still re-verifies Name client-side when the server returns a non-matching view' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{ data = @($script:viewData) }
        }

        @(Get-DMMappingView -WebSession $script:session -Name 'does-not-exist') | Should -BeNullOrEmpty
    }

    It 'returns no mapping views when the API contains no data property' {
        Mock Invoke-DeviceManager { [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } } }

        @(Get-DMMappingView -WebSession $script:session -PortGroupName 'front-end') | Should -BeNullOrEmpty
    }

    It 'removes a resolved mapping view by ID' {
        Mock Get-DMMappingView { @($script:view) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMMappingView -WebSession $script:session -MappingViewName 'application' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'mappingview/mv-01?vstoreId=7'
    }

    It 'removes every mapping view piped in, not just the last one' {
        Mock Get-DMMappingView {
            @(
                [pscustomobject]@{ Id = 'mv-01'; Name = 'view-a' }
                [pscustomobject]@{ Id = 'mv-02'; Name = 'view-b' }
            )
        }
        $resources = [System.Collections.Generic.List[string]]::new()
        Mock Invoke-DeviceManager {
            $resources.Add($Resource)
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $items = @([pscustomobject]@{ Name = 'view-a' }, [pscustomobject]@{ Name = 'view-b' })
        $null = $items | Remove-DMMappingView -WebSession $script:session -Confirm:$false

        $resources | Should -Contain 'mappingview/mv-01'
        $resources | Should -Contain 'mappingview/mv-02'
    }

    It 'exposes completion metadata for mapping view group filters' {
        $command = Get-Command Get-DMMappingView

        foreach ($parameterName in @('HostGroupName', 'LunGroupName', 'PortGroupName')) {
            @($command.Parameters[$parameterName].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                Should -BeGreaterThan 0 -Because "Get-DMMappingView -$parameterName should support tab completion"
        }
    }
}

Describe 'Mapping view association commands' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:view = [OceanStorMappingView]::new([pscustomobject]@{ ID = 'mv-01'; NAME = 'application' }, $script:session)
        Mock Get-DMMappingView { @($script:view) }
        Mock Get-DMhostGroup {
            param($WebSession, $Name, $Id)
            $groups = @([pscustomobject]@{ Id = 'hg-01'; Name = 'cluster01' })
            if ($Id) {
                return @($groups | Where-Object Id -EQ $Id)
            }
            if ($Name) {
                return @($groups | Where-Object Name -EQ $Name)
            }
            return $groups
        }
        Mock Get-DMlunGroup {
            param($WebSession, $Name, $Id)
            $groups = @([pscustomobject]@{ Id = 'lg-01'; Name = 'production' })
            if ($Id) {
                return @($groups | Where-Object Id -EQ $Id)
            }
            if ($Name) {
                return @($groups | Where-Object Name -EQ $Name)
            }
            return $groups
        }
        Mock Get-DMPortGroup { @([pscustomobject]@{ Id = 'pg-01'; Name = 'front-end' }) }
        Mock Get-DMhost {
            param($WebSession, $Name, $Id)
            $hosts = @([pscustomobject]@{ Id = 'host-01'; Name = 'esx01' })
            if ($Id) {
                return @($hosts | Where-Object Id -EQ $Id)
            }
            if ($Name) {
                return @($hosts | Where-Object Name -EQ $Name)
            }
            return $hosts
        }
        Mock Get-DMlun {
            param($WebSession, $Name, $Id)
            $luns = @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' })
            if ($Id) {
                return @($luns | Where-Object Id -EQ $Id)
            }
            if ($Name) {
                return @($luns | Where-Object Name -EQ $Name)
            }
            return $luns
        }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            $script:apiV2 = $ApiV2.IsPresent
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'mv-02'; NAME = 'map_auto'; TYPE = 245 } }
        }
    }

    It 'adds a host group to a mapping view' {
        $result = Add-DMHostGroupToMappingView -WebSession $script:session -MappingViewName 'application' -HostGroupName 'cluster01' -VstoreId '7' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'mappingview/CREATE_ASSOCIATE'
        $script:request.ID | Should -Be 'mv-01'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 14
        $script:request.ASSOCIATEOBJID | Should -Be 'hg-01'
        $script:request.vstoreId | Should -Be '7'
    }

    It 'adds LUN and port groups with their mapping REST object types' {
        $null = Add-DMLunGroupToMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'production' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 256
        $script:request.ASSOCIATEOBJID | Should -Be 'lg-01'

        $null = Add-DMPortGroupToMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'front-end' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 257
        $script:request.ASSOCIATEOBJID | Should -Be 'pg-01'
    }

    It 'removes each verified group association through the modification interface' {
        $null = Remove-DMHostGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -HostGroupName 'cluster01' -Confirm:$false
        $script:resource | Should -Be 'mappingview/REMOVE_ASSOCIATE'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 14

        $null = Remove-DMLunGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'production' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 256

        $null = Remove-DMPortGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'front-end' -Confirm:$false
        $script:request.ASSOCIATEOBJTYPE | Should -Be 257
    }

    It 'removes every LUN group piped in from the mapping view, not just the last one' {
        Mock Get-DMlunGroup {
            @(
                [pscustomobject]@{ Id = 'lg-01'; Name = 'group-a' }
                [pscustomobject]@{ Id = 'lg-02'; Name = 'group-b' }
            )
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $groups = @(
            [pscustomobject]@{ Name = 'group-a' }
            [pscustomobject]@{ Name = 'group-b' }
        )
        $null = $groups | Remove-DMLunGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -Confirm:$false

        $putRequests = @($requests | Where-Object Resource -EQ 'mappingview/REMOVE_ASSOCIATE')
        $putRequests.Count | Should -Be 2
        ($putRequests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'lg-01' }).Count | Should -Be 1
        ($putRequests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'lg-02' }).Count | Should -Be 1
    }

    It 'associates every host group piped in with the mapping view, not just the last one' {
        Mock Get-DMhostGroup {
            @(
                [pscustomobject]@{ Id = 'hg-01'; Name = 'group-a' }
                [pscustomobject]@{ Id = 'hg-02'; Name = 'group-b' }
            )
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $groups = @([pscustomobject]@{ Name = 'group-a' }, [pscustomobject]@{ Name = 'group-b' })
        $null = $groups | Add-DMHostGroupToMappingView -WebSession $script:session -MappingViewName 'application' -Confirm:$false

        $putRequests = @($requests | Where-Object Resource -EQ 'mappingview/CREATE_ASSOCIATE')
        $putRequests.Count | Should -Be 2
        ($putRequests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'hg-01' }).Count | Should -Be 1
        ($putRequests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'hg-02' }).Count | Should -Be 1
    }

    It 'removes every host group piped in from the mapping view, not just the last one' {
        Mock Get-DMhostGroup {
            @(
                [pscustomobject]@{ Id = 'hg-01'; Name = 'group-a' }
                [pscustomobject]@{ Id = 'hg-02'; Name = 'group-b' }
            )
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Resource = $Resource; Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $groups = @([pscustomobject]@{ Name = 'group-a' }, [pscustomobject]@{ Name = 'group-b' })
        $null = $groups | Remove-DMHostGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -Confirm:$false

        $putRequests = @($requests | Where-Object Resource -EQ 'mappingview/REMOVE_ASSOCIATE')
        $putRequests.Count | Should -Be 2
        ($putRequests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'hg-01' }).Count | Should -Be 1
        ($putRequests | Where-Object { $_.Body.ASSOCIATEOBJID -eq 'hg-02' }).Count | Should -Be 1
    }

    It 'reports a non-terminating error when the group is not associated with the mapping view' {
        Mock Get-DMMappingView {
            if ($PortGroupName) { return @() }
            return @($script:view)
        }

        $result = Remove-DMPortGroupFromMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'front-end' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable removeErrors

        $result | Should -BeNullOrEmpty
        $removeErrors.Count | Should -BeGreaterOrEqual 1
        ($removeErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*not associated*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'honors WhatIf for association creation' {
        $null = Add-DMLunGroupToMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'production' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for an unknown LUN group association target' {
        $result = Add-DMLunGroupToMappingView -WebSession $script:session -MappingViewName 'application' -LunGroupName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable addErrors

        $result | Should -BeNullOrEmpty
        $addErrors.Count | Should -BeGreaterOrEqual 1
        ($addErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid LunGroupName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'reports a non-terminating error for an unknown port group association target' {
        $result = Add-DMPortGroupToMappingView -WebSession $script:session -MappingViewName 'application' -PortGroupName 'missing' -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable addErrors

        $result | Should -BeNullOrEmpty
        $addErrors.Count | Should -BeGreaterOrEqual 1
        ($addErrors.Exception.Message | Select-Object -Unique) | Should -BeLike '*Invalid PortGroupName*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'exposes completion metadata for mapping association references' {
        $referenceParameters = @{
            'Add-DMHostGroupToMappingView'      = @('MappingViewName', 'HostGroupName')
            'Add-DMLunGroupToMappingView'       = @('MappingViewName', 'LunGroupName')
            'Add-DMPortGroupToMappingView'      = @('MappingViewName', 'PortGroupName')
            'Remove-DMHostGroupFromMappingView' = @('MappingViewName', 'HostGroupName')
            'Remove-DMLunGroupFromMappingView'  = @('MappingViewName', 'LunGroupName')
            'Remove-DMPortGroupFromMappingView' = @('MappingViewName', 'PortGroupName')
        }

        foreach ($commandName in $referenceParameters.Keys) {
            $command = Get-Command $commandName
            foreach ($parameterName in $referenceParameters[$commandName]) {
                @($command.Parameters[$parameterName].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                    Should -BeGreaterThan 0 -Because "$commandName -$parameterName should support tab completion"
            }
        }
    }

    It '<Command> maps/unmaps a LUN and host validated as parameters' -TestCases @(
        @{ Command = 'Add-DMmapLunToHost'; Method = 'POST'; ExpectedApiV2 = $true }
        @{ Command = 'Remove-DMmapLunFromHost'; Method = 'DELETE'; ExpectedApiV2 = $false }
    ) {
        param($Command, $Method, $ExpectedApiV2)

        $result = & $Command -WebSession $script:session -LunName 'data-lun' -HostName 'esx01' -VstoreId '7' -Confirm:$false

        $script:method | Should -Be $Method
        $script:resource | Should -Be 'mapping'
        $script:apiV2 | Should -Be $ExpectedApiV2
        $script:request.hostId | Should -Be 'host-01'
        $script:request.lunId | Should -Be 'lun-01'
        $script:request.vstoreId | Should -Be '7'
        if ($Method -eq 'POST') {
            $result.GetType().Name | Should -Be 'OceanStorMappingView'
        }
        else {
            $result.Code | Should -Be 0
        }
    }

    It '<Command> rejects an unknown LunName at parameter binding, with a short error message' -TestCases @(
        @{ Command = 'Add-DMmapLunToHost' }
        @{ Command = 'Remove-DMmapLunFromHost' }
    ) {
        param($Command)

        { & $Command -WebSession $script:session -LunName 'missing' -HostName 'esx01' -Confirm:$false } |
            Should -Throw '*Invalid LunName.*'

        try {
            & $Command -WebSession $script:session -LunName 'missing' -HostName 'esx01' -Confirm:$false
        }
        catch {
            $_.Exception.Message | Should -Not -BeLike '*Valid values are*'
        }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> rejects an unknown HostName at parameter binding, with a short error message' -TestCases @(
        @{ Command = 'Add-DMmapLunToHost' }
        @{ Command = 'Remove-DMmapLunFromHost' }
    ) {
        param($Command)

        { & $Command -WebSession $script:session -LunName 'data-lun' -HostName 'missing' -Confirm:$false } |
            Should -Throw '*Invalid HostName.*'

        try {
            & $Command -WebSession $script:session -LunName 'data-lun' -HostName 'missing' -Confirm:$false
        }
        catch {
            $_.Exception.Message | Should -Not -BeLike '*Valid values are*'
        }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'exposes completion metadata for Add-DMmapLunToHost/Remove-DMmapLunFromHost LunName and HostName' {
        foreach ($commandName in @('Add-DMmapLunToHost', 'Remove-DMmapLunFromHost')) {
            $command = Get-Command $commandName
            foreach ($parameterName in @('LunName', 'HostName')) {
                @($command.Parameters[$parameterName].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                    Should -BeGreaterThan 0 -Because "$commandName -$parameterName should support tab completion"
            }
        }
    }

    It 'maps every LUN piped into Add-DMmapLunToHost to the same host, not just the last one' {
        Mock Get-DMlun {
            param($WebSession, $Name, $Id)
            @([pscustomobject]@{ Id = 'lun-01'; Name = 'data-lun' }, [pscustomobject]@{ Id = 'lun-02'; Name = 'archive-lun' } | Where-Object Name -EQ $Name)
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'mv-02'; NAME = 'map_auto'; TYPE = 245 } }
        }

        $luns = @([pscustomobject]@{ Name = 'data-lun' }, [pscustomobject]@{ Name = 'archive-lun' })
        $null = $luns | Add-DMmapLunToHost -WebSession $script:session -HostName 'esx01' -Confirm:$false

        $requests.Count | Should -Be 2
        ($requests | Where-Object { $_.Body.lunId -eq 'lun-01' }).Count | Should -Be 1
        ($requests | Where-Object { $_.Body.lunId -eq 'lun-02' }).Count | Should -Be 1
    }

    It 'honors WhatIf for Add-DMmapLunToHost' {
        $null = Add-DMmapLunToHost -WebSession $script:session -LunName 'data-lun' -HostName 'esx01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> maps/unmaps a LUN group to a host, validated as parameters' -TestCases @(
        @{ Command = 'Add-DMmapLunGroupToHost'; Method = 'POST'; ExpectedApiV2 = $true }
        @{ Command = 'Remove-DMunmapLunGroupFromHost'; Method = 'DELETE'; ExpectedApiV2 = $false }
    ) {
        param($Command, $Method, $ExpectedApiV2)

        $result = & $Command -WebSession $script:session -LunGroupName 'production' -HostName 'esx01' -VstoreId '7' -Confirm:$false

        $script:method | Should -Be $Method
        $script:resource | Should -Be 'mapping'
        $script:apiV2 | Should -Be $ExpectedApiV2
        $script:request.hostId | Should -Be 'host-01'
        $script:request.lunGroupId | Should -Be 'lg-01'
        $script:request.vstoreId | Should -Be '7'
        if ($Method -eq 'POST') {
            $result.GetType().Name | Should -Be 'OceanStorMappingView'
        }
        else {
            $result.Code | Should -Be 0
        }
    }

    It '<Command> maps/unmaps a LUN group to a host group, validated as parameters' -TestCases @(
        @{ Command = 'Add-DMmapLunGroupToHostGroup'; Method = 'POST'; ExpectedApiV2 = $true }
        @{ Command = 'Remove-DMunmapLunGroupFromHostGroup'; Method = 'DELETE'; ExpectedApiV2 = $false }
    ) {
        param($Command, $Method, $ExpectedApiV2)

        $result = & $Command -WebSession $script:session -LunGroupName 'production' -HostGroupName 'cluster01' -VstoreId '7' -Confirm:$false

        $script:method | Should -Be $Method
        $script:resource | Should -Be 'mapping'
        $script:apiV2 | Should -Be $ExpectedApiV2
        $script:request.hostGroupId | Should -Be 'hg-01'
        $script:request.lunGroupId | Should -Be 'lg-01'
        $script:request.vstoreId | Should -Be '7'
        if ($Method -eq 'POST') {
            $result.GetType().Name | Should -Be 'OceanStorMappingView'
        }
        else {
            $result.Code | Should -Be 0
        }
    }

    It '<Command> rejects an unknown LunGroupName at parameter binding, with a short error message' -TestCases @(
        @{ Command = 'Add-DMmapLunGroupToHost'; Parameters = @{ HostName = 'esx01' } }
        @{ Command = 'Remove-DMunmapLunGroupFromHost'; Parameters = @{ HostName = 'esx01' } }
        @{ Command = 'Add-DMmapLunGroupToHostGroup'; Parameters = @{ HostGroupName = 'cluster01' } }
        @{ Command = 'Remove-DMunmapLunGroupFromHostGroup'; Parameters = @{ HostGroupName = 'cluster01' } }
    ) {
        param($Command, $Parameters)

        { & $Command -WebSession $script:session -LunGroupName 'missing' -Confirm:$false @Parameters } |
            Should -Throw '*Invalid LunGroupName.*'

        try {
            & $Command -WebSession $script:session -LunGroupName 'missing' -Confirm:$false @Parameters
        }
        catch {
            $_.Exception.Message | Should -Not -BeLike '*Valid values are*'
        }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> rejects an unknown HostName at parameter binding, with a short error message' -TestCases @(
        @{ Command = 'Add-DMmapLunGroupToHost' }
        @{ Command = 'Remove-DMunmapLunGroupFromHost' }
    ) {
        param($Command)

        { & $Command -WebSession $script:session -LunGroupName 'production' -HostName 'missing' -Confirm:$false } |
            Should -Throw '*Invalid HostName.*'

        try {
            & $Command -WebSession $script:session -LunGroupName 'production' -HostName 'missing' -Confirm:$false
        }
        catch {
            $_.Exception.Message | Should -Not -BeLike '*Valid values are*'
        }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> rejects an unknown HostGroupName at parameter binding, with a short error message' -TestCases @(
        @{ Command = 'Add-DMmapLunGroupToHostGroup' }
        @{ Command = 'Remove-DMunmapLunGroupFromHostGroup' }
    ) {
        param($Command)

        { & $Command -WebSession $script:session -LunGroupName 'production' -HostGroupName 'missing' -Confirm:$false } |
            Should -Throw '*Invalid HostGroupName.*'

        try {
            & $Command -WebSession $script:session -LunGroupName 'production' -HostGroupName 'missing' -Confirm:$false
        }
        catch {
            $_.Exception.Message | Should -Not -BeLike '*Valid values are*'
        }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'exposes completion metadata for the LUN-group mapping commands' {
        $referenceParameters = @{
            'Add-DMmapLunGroupToHost'             = @('LunGroupName', 'HostName')
            'Add-DMmapLunGroupToHostGroup'         = @('LunGroupName', 'HostGroupName')
            'Remove-DMunmapLunGroupFromHost'       = @('LunGroupName', 'HostName')
            'Remove-DMunmapLunGroupFromHostGroup'  = @('LunGroupName', 'HostGroupName')
        }

        foreach ($commandName in $referenceParameters.Keys) {
            $command = Get-Command $commandName
            foreach ($parameterName in $referenceParameters[$commandName]) {
                @($command.Parameters[$parameterName].Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                    Should -BeGreaterThan 0 -Because "$commandName -$parameterName should support tab completion"
            }
        }
    }

    It 'maps every LUN group piped into Add-DMmapLunGroupToHost to the same host, not just the last one' {
        Mock Get-DMlunGroup {
            param($WebSession, $Name)
            $groups = @([pscustomobject]@{ Id = 'lg-01'; Name = 'group-a' }, [pscustomobject]@{ Id = 'lg-02'; Name = 'group-b' })
            if ($Name) {
                return @($groups | Where-Object Name -EQ $Name)
            }
            return $groups
        }
        $requests = [System.Collections.Generic.List[object]]::new()
        Mock Invoke-DeviceManager {
            $requests.Add([pscustomobject]@{ Body = $BodyData })
            [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 }; data = [pscustomobject]@{ ID = 'mv-02'; NAME = 'map_auto'; TYPE = 245 } }
        }

        $groups = @([pscustomobject]@{ Name = 'group-a' }, [pscustomobject]@{ Name = 'group-b' })
        $null = $groups | Add-DMmapLunGroupToHost -WebSession $script:session -HostName 'esx01' -Confirm:$false

        $requests.Count | Should -Be 2
        ($requests | Where-Object { $_.Body.lunGroupId -eq 'lg-01' }).Count | Should -Be 1
        ($requests | Where-Object { $_.Body.lunGroupId -eq 'lg-02' }).Count | Should -Be 1
    }

    It 'honors WhatIf for Add-DMmapLunGroupToHost and Add-DMmapLunGroupToHostGroup' {
        $null = Add-DMmapLunGroupToHost -WebSession $script:session -LunGroupName 'production' -HostName 'esx01' -WhatIf
        $null = Add-DMmapLunGroupToHostGroup -WebSession $script:session -LunGroupName 'production' -HostGroupName 'cluster01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> maps/unmaps by Id, validated but with no tab completion' -TestCases @(
        @{ Command = 'Add-DMmapLunToHost'; Method = 'POST'; ExpectedApiV2 = $true; Parameters = @{ LunId = 'lun-01'; HostId = 'host-01' }; BodyKeys = @{ lunId = 'lun-01'; hostId = 'host-01' } }
        @{ Command = 'Remove-DMmapLunFromHost'; Method = 'DELETE'; ExpectedApiV2 = $false; Parameters = @{ LunId = 'lun-01'; HostId = 'host-01' }; BodyKeys = @{ lunId = 'lun-01'; hostId = 'host-01' } }
        @{ Command = 'Add-DMmapLunGroupToHost'; Method = 'POST'; ExpectedApiV2 = $true; Parameters = @{ LunGroupId = 'lg-01'; HostId = 'host-01' }; BodyKeys = @{ lunGroupId = 'lg-01'; hostId = 'host-01' } }
        @{ Command = 'Remove-DMunmapLunGroupFromHost'; Method = 'DELETE'; ExpectedApiV2 = $false; Parameters = @{ LunGroupId = 'lg-01'; HostId = 'host-01' }; BodyKeys = @{ lunGroupId = 'lg-01'; hostId = 'host-01' } }
        @{ Command = 'Add-DMmapLunGroupToHostGroup'; Method = 'POST'; ExpectedApiV2 = $true; Parameters = @{ LunGroupId = 'lg-01'; HostGroupId = 'hg-01' }; BodyKeys = @{ lunGroupId = 'lg-01'; hostGroupId = 'hg-01' } }
        @{ Command = 'Remove-DMunmapLunGroupFromHostGroup'; Method = 'DELETE'; ExpectedApiV2 = $false; Parameters = @{ LunGroupId = 'lg-01'; HostGroupId = 'hg-01' }; BodyKeys = @{ lunGroupId = 'lg-01'; hostGroupId = 'hg-01' } }
    ) {
        param($Command, $Method, $ExpectedApiV2, $Parameters, $BodyKeys)

        $result = & $Command -WebSession $script:session -Confirm:$false @Parameters

        $script:method | Should -Be $Method
        $script:resource | Should -Be 'mapping'
        $script:apiV2 | Should -Be $ExpectedApiV2
        foreach ($key in $BodyKeys.Keys) {
            $script:request.$key | Should -Be $BodyKeys[$key]
        }
        if ($Method -eq 'POST') {
            $result.GetType().Name | Should -Be 'OceanStorMappingView'
        }
        else {
            $result.Code | Should -Be 0
        }

        $command = Get-Command $Command
        foreach ($idParameterName in $Parameters.Keys) {
            @($command.Parameters[$idParameterName].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ArgumentCompleterAttribute] }).Count |
                Should -Be 0 -Because "$Command -$idParameterName should not support tab completion"
        }
    }

    It '<Command> rejects supplying both Name and Id for the same slot' -TestCases @(
        @{ Command = 'Add-DMmapLunToHost'; Parameters = @{ LunName = 'data-lun'; LunId = 'lun-01'; HostName = 'esx01' } }
        @{ Command = 'Add-DMmapLunToHost'; Parameters = @{ LunName = 'data-lun'; HostName = 'esx01'; HostId = 'host-01' } }
        @{ Command = 'Remove-DMmapLunFromHost'; Parameters = @{ LunName = 'data-lun'; LunId = 'lun-01'; HostName = 'esx01' } }
        @{ Command = 'Add-DMmapLunGroupToHost'; Parameters = @{ LunGroupName = 'production'; LunGroupId = 'lg-01'; HostName = 'esx01' } }
        @{ Command = 'Add-DMmapLunGroupToHost'; Parameters = @{ LunGroupName = 'production'; HostName = 'esx01'; HostId = 'host-01' } }
        @{ Command = 'Remove-DMunmapLunGroupFromHost'; Parameters = @{ LunGroupName = 'production'; LunGroupId = 'lg-01'; HostName = 'esx01' } }
        @{ Command = 'Add-DMmapLunGroupToHostGroup'; Parameters = @{ LunGroupName = 'production'; LunGroupId = 'lg-01'; HostGroupName = 'cluster01' } }
        @{ Command = 'Add-DMmapLunGroupToHostGroup'; Parameters = @{ LunGroupName = 'production'; HostGroupName = 'cluster01'; HostGroupId = 'hg-01' } }
        @{ Command = 'Remove-DMunmapLunGroupFromHostGroup'; Parameters = @{ LunGroupName = 'production'; HostGroupName = 'cluster01'; HostGroupId = 'hg-01' } }
    ) {
        param($Command, $Parameters)

        { & $Command -WebSession $script:session -Confirm:$false @Parameters } | Should -Throw '*parameter set*'
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It '<Command> rejects an unknown Id at parameter binding, with a short error message' -TestCases @(
        @{ Command = 'Add-DMmapLunToHost'; Parameters = @{ LunId = 'missing'; HostName = 'esx01' }; ExpectedMessage = '*Invalid LunId.*' }
        @{ Command = 'Add-DMmapLunToHost'; Parameters = @{ LunName = 'data-lun'; HostId = 'missing' }; ExpectedMessage = '*Invalid HostId.*' }
        @{ Command = 'Add-DMmapLunGroupToHost'; Parameters = @{ LunGroupId = 'missing'; HostName = 'esx01' }; ExpectedMessage = '*Invalid LunGroupId.*' }
        @{ Command = 'Add-DMmapLunGroupToHostGroup'; Parameters = @{ LunGroupName = 'production'; HostGroupId = 'missing' }; ExpectedMessage = '*Invalid HostGroupId.*' }
    ) {
        param($Command, $Parameters, $ExpectedMessage)

        { & $Command -WebSession $script:session -Confirm:$false @Parameters } | Should -Throw $ExpectedMessage

        try {
            & $Command -WebSession $script:session -Confirm:$false @Parameters
        }
        catch {
            $_.Exception.Message | Should -Not -BeLike '*Valid values are*'
        }
        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}
}
