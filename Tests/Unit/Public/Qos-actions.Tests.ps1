BeforeDiscovery {
    $script:qosModule = New-Module -Name QosActionsTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMlun { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMFileSystem { param([pscustomobject]$WebSession) }
        function Get-DMlunGroup { param([pscustomobject]$WebSession, [string]$Name) }
        function Get-DMhost { param([pscustomobject]$WebSession, [string]$Name) }
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

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Assert-DMApiSuccess.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Invoke-DMPagedRequest.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\New-DMNamedObjectUpdate.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\New-DMQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Set-DMQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Start-DMQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Stop-DMQosPolicy.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Add-DMQosAssociation.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Remove-DMQosAssociation.ps1"

        Export-ModuleMember -Function 'New-DMQosPolicy', 'Get-DMQosPolicy', 'Set-DMQosPolicy', 'Remove-DMQosPolicy', 'Start-DMQosPolicy', 'Stop-DMQosPolicy', 'Add-DMQosAssociation', 'Remove-DMQosAssociation' -Alias 'Enable-DMQosPolicy', 'Disable-DMQosPolicy'
    }
    Import-Module $script:qosModule -Force
}

AfterAll {
    Remove-Module -Name QosActionsTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope QosActionsTestModule {
Describe 'New-DMQosPolicy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlun { @([pscustomobject]@{ Id = 'lun-01'; Name = 'lun01' }) }
        Mock Get-DMFileSystem { @([pscustomobject]@{ Id = 'fs-01'; Name = 'documents' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = [pscustomobject]@{ ID = 'qos-01'; NAME = $BodyData.NAME }
            }
        }
    }

    It 'creates a policy with a bandwidth limit and schedule fields' {
        $result = New-DMQosPolicy -WebSession $script:session -Name 'qos01' -MaxIOPS 5000 `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false

        $result.GetType().Name | Should -Be 'OceanstorQosPolicy'
        $script:method | Should -Be 'POST'
        $script:resource | Should -Be 'ioclass'
        $script:request.NAME | Should -Be 'qos01'
        $script:request.MAXIOPS | Should -Be 5000
        $script:request.STARTTIME | Should -Be '00:00'
        $script:request.DURATION | Should -Be 3600
        $script:request.SCHEDULEPOLICY | Should -Be 0
        $script:request.IOTYPE | Should -Be 2
        # PRIORITY must NOT be sent by default: some firmware rejects any PRIORITY value on an
        # ioclass create with the generic 50331651 error. See the dedicated regression test below.
        $script:request.ContainsKey('PRIORITY') | Should -BeFalse
    }

    It 'omits PRIORITY from the create body by default but includes it when -Priority is passed' {
        # Regression: PRIORITY was previously placed in the body unconditionally (default Normal->0),
        # which the array rejects with API error 50331651 on every create. It must only be sent when
        # the caller explicitly supplies -Priority.
        $null = New-DMQosPolicy -WebSession $script:session -Name 'qos_default' -MaxIOPS 5000 `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false
        $script:request.ContainsKey('PRIORITY') | Should -BeFalse

        $null = New-DMQosPolicy -WebSession $script:session -Name 'qos_high' -MaxIOPS 5000 -Priority High `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false
        $script:request.ContainsKey('PRIORITY') | Should -BeTrue
        $script:request.PRIORITY | Should -Be 1
    }

    It 'resolves LunName entries to LUNLIST' {
        $null = New-DMQosPolicy -WebSession $script:session -Name 'qos02' -MaxBandwidth 500 `
            -LunName 'lun01' -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false

        $script:request.LUNLIST | Should -Be @('lun-01')
    }

    It 'resolves FileSystemName entries to FSLIST' {
        $null = New-DMQosPolicy -WebSession $script:session -Name 'qos03' -MaxBandwidth 500 `
            -FileSystemName 'documents' -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false

        $script:request.FSLIST | Should -Be @('fs-01')
    }

    It 'resolves a LunName longer than the 31-char policy-name limit without tripping the Name validator' {
        # Regression: the LunName resolution loop previously used $name, which is
        # the same variable as the validated $Name parameter (PowerShell names are
        # case-insensitive). A LUN renamed to >31 chars therefore re-triggered
        # $Name's ValidateLength(1,31) and threw before any REST call.
        $longLun = 'dm_integrity_20260708004451_lun_renamed'  # 39 chars, all valid characters
        Mock Get-DMlun { @([pscustomobject]@{ Id = 'lun-long'; Name = $longLun }) }

        { New-DMQosPolicy -WebSession $script:session -Name 'qos_regress' -MaxIOPS 5000 `
                -LunName $longLun -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 `
                -Confirm:$false -ErrorAction Stop } | Should -Not -Throw

        $script:request.NAME | Should -Be 'qos_regress'   # $Name not corrupted by the loop
        $script:request.LUNLIST | Should -Be @('lun-long')
    }

    It 'rejects a create call with no bandwidth/IOPS/latency limit specified' {
        { New-DMQosPolicy -WebSession $script:session -Name 'qos04' -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*Specify at least one*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects BurstBandwidth without BurstTime' {
        { New-DMQosPolicy -WebSession $script:session -Name 'qos05' -MaxIOPS 5000 -BurstBandwidth 100 `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*BurstTime*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects a Weekly schedule without CycleSet' {
        { New-DMQosPolicy -WebSession $script:session -Name 'qos06' -MaxIOPS 5000 -SchedulePolicy Weekly `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*CycleSet*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'rejects specifying both LunName and FileSystemName' {
        { New-DMQosPolicy -WebSession $script:session -Name 'qos07' -MaxIOPS 5000 -LunName 'lun01' -FileSystemName 'documents' `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*mutually exclusive*'

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }

    It 'does not create when WhatIf is specified' {
        $null = New-DMQosPolicy -WebSession $script:session -Name 'qos08' -MaxIOPS 5000 `
            -ScheduleStartTime (Get-Date) -StartTime '00:00' -Duration 3600 -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly
    }
}

Describe 'Get-DMQosPolicy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
    }

    It 'gets every policy when no selector is supplied' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{
                data = @(
                    [pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01' }
                    [pscustomobject]@{ ID = 'qos-02'; NAME = 'qos02' }
                )
            }
        }

        $result = @(Get-DMQosPolicy -WebSession $script:session)

        $result.Count | Should -Be 2
        $script:resource | Should -BeLike 'ioclass?range=*'
    }

    It 'filters by exact name' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01' }) }
        }

        $result = Get-DMQosPolicy -WebSession $script:session -Name 'qos01'

        $result.Name | Should -Be 'qos01'
        $script:resource | Should -BeLike 'ioclass?filter=NAME::qos01*'
    }

    It 'fetches by Id' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01' }) }
        }

        $result = Get-DMQosPolicy -WebSession $script:session -Id 'qos-01'

        $result.Id | Should -Be 'qos-01'
        $script:resource | Should -BeLike 'ioclass?filter=ID::qos-01*'
    }

    It 'uses a fuzzy filter when a wildcard is present in Name' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @() }
        }

        $null = Get-DMQosPolicy -WebSession $script:session -Name 'qos*'

        $script:resource | Should -BeLike 'ioclass?filter=NAME:qos*'
    }

    It 'searches by ParentPolicyId' {
        Mock Invoke-DeviceManager {
            $script:resource = $Resource
            [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-child'; NAME = 'child'; PARENTPOLICYID = 'qos-01' }) }
        }

        $result = Get-DMQosPolicy -WebSession $script:session -ParentPolicyId 'qos-01'

        $result.'Parent Policy Id' | Should -Be 'qos-01'
        $script:resource | Should -BeLike 'ioclass?filter=PARENTPOLICYID::qos-01*'
    }
}

Describe 'Set-DMQosPolicy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'modifies MaxIOPS by name' {
        $result = Set-DMQosPolicy -WebSession $script:session -Name 'qos01' -MaxIOPS 8000 -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'PUT'
        $script:resource | Should -Be 'ioclass/qos-01'
        $script:request.MAXIOPS | Should -Be 8000
    }

    It 'rejects BurstBandwidth without BurstTime' {
        { Set-DMQosPolicy -WebSession $script:session -Name 'qos01' -BurstBandwidth 100 -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*BurstTime*'
    }

    It 'does not modify when WhatIf is specified' {
        $null = Set-DMQosPolicy -WebSession $script:session -Name 'qos01' -MaxIOPS 8000 -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Method -eq 'PUT' }
    }
}

Describe 'Remove-DMQosPolicy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                # Default: an already-stopped policy (Running Status 45 = 'Inactive'), so Remove
                # deletes straight away without the stop-then-delete detour.
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01'; RUNNINGSTATUS = '45' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'removes a policy by name' {
        $result = Remove-DMQosPolicy -WebSession $script:session -Name 'qos01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:method | Should -Be 'DELETE'
        $script:resource | Should -Be 'ioclass/qos-01'
    }

    It 'removes a policy by Id' {
        $result = Remove-DMQosPolicy -WebSession $script:session -Id 'qos-01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:resource | Should -Be 'ioclass/qos-01'
    }

    It 'stops a running policy before deleting it' {
        # ioclass/active drives Running Status (start/stop), not ENABLESTATUS. The array refuses
        # to delete a running policy, so Remove must stop it (PUT ioclass/active ENABLESTATUS=$false)
        # and wait for Running Status 'Inactive' before issuing the DELETE.
        $script:calls = [System.Collections.Generic.List[object]]::new()
        $script:stopped = $false
        Mock Invoke-DeviceManager {
            $script:calls.Add(@{ Method = $Method; Resource = $Resource; Body = $BodyData })
            # The stop (PUT ioclass/active with ENABLESTATUS=$false) is what moves the policy to
            # 'Inactive'. Report Running (2) until that happens, then Inactive (45) so the bounded
            # settle poll exits. Robust to the extra GET that the -Id ValidateScript performs.
            if ($Method -eq 'PUT' -and $Resource -eq 'ioclass/active') { $script:stopped = $true }
            if ($Method -eq 'GET') {
                $status = if ($script:stopped) { '45' } else { '2' }
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01'; RUNNINGSTATUS = $status }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }

        $result = Remove-DMQosPolicy -WebSession $script:session -Id 'qos-01' -Confirm:$false

        $result.Code | Should -Be 0
        $deactivate = $script:calls | Where-Object { $_.Method -eq 'PUT' -and $_.Resource -eq 'ioclass/active' }
        $deactivate | Should -Not -BeNullOrEmpty
        $deactivate.Body.ENABLESTATUS | Should -BeFalse
        ($script:calls | Where-Object { $_.Method -eq 'DELETE' }).Resource | Should -Be 'ioclass/qos-01'
        # The DELETE must come after the stop (PUT ioclass/active).
        $methods = @($script:calls | ForEach-Object { $_.Method })
        $putPos = [array]::IndexOf($methods, 'PUT')
        $delPos = [array]::IndexOf($methods, 'DELETE')
        $putPos | Should -BeGreaterOrEqual 0
        $delPos | Should -BeGreaterThan $putPos
    }

    It 'rejects an unknown name' {
        { Remove-DMQosPolicy -WebSession $script:session -Name 'missing' -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*Invalid Name*'
    }

    It 'does not remove when WhatIf is specified' {
        $null = Remove-DMQosPolicy -WebSession $script:session -Name 'qos01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Method -eq 'DELETE' }
    }
}

Describe 'Start-DMQosPolicy and Stop-DMQosPolicy' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{ data = @([pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01' }) }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'starts a policy (Running Status active) with ENABLESTATUS true' {
        $result = Start-DMQosPolicy -WebSession $script:session -Name 'qos01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:resource | Should -Be 'ioclass/active'
        $script:request.ID | Should -Be 'qos-01'
        $script:request.ENABLESTATUS | Should -BeTrue
    }

    It 'stops a policy (Running Status inactive) with ENABLESTATUS false' {
        $result = Stop-DMQosPolicy -WebSession $script:session -Name 'qos01' -Confirm:$false

        $result.Code | Should -Be 0
        $script:resource | Should -Be 'ioclass/active'
        $script:request.ENABLESTATUS | Should -BeFalse
    }

    It 'does not start when WhatIf is specified' {
        $null = Start-DMQosPolicy -WebSession $script:session -Name 'qos01' -WhatIf

        Should -Invoke Invoke-DeviceManager -Times 0 -Exactly -ParameterFilter { $Method -eq 'PUT' }
    }

    It 'exposes Enable-DMQosPolicy as a backward-compatibility alias of Start-DMQosPolicy' {
        (Get-Alias -Name 'Enable-DMQosPolicy').ResolvedCommandName | Should -Be 'Start-DMQosPolicy'
    }

    It 'exposes Disable-DMQosPolicy as a backward-compatibility alias of Stop-DMQosPolicy' {
        (Get-Alias -Name 'Disable-DMQosPolicy').ResolvedCommandName | Should -Be 'Stop-DMQosPolicy'
    }
}

Describe 'Add-DMQosAssociation and Remove-DMQosAssociation' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        Mock Get-DMlunGroup { @([pscustomobject]@{ Id = 'lg-01'; Name = 'production-luns' }) }
        Mock Get-DMhost { @([pscustomobject]@{ Id = 'host-01'; Name = 'esx01' }) }
        Mock Get-DMvStore { @([pscustomobject]@{ Id = 'vs-01'; Name = 'vstore01' }) }
        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            $script:request = $BodyData
            if ($Method -eq 'GET') {
                return [pscustomobject]@{
                    data = @(
                        [pscustomobject]@{ ID = 'qos-01'; NAME = 'qos01-parent' }
                        [pscustomobject]@{ ID = 'qos-02'; NAME = 'qos01-child' }
                    )
                }
            }
            return [pscustomobject]@{ error = [pscustomobject]@{ Code = 0 } }
        }
    }

    It 'associates a LUN group with type 256' {
        $null = Add-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -LunGroupName 'production-luns' -Confirm:$false

        $script:resource | Should -Be 'ioclass/create_associate'
        $script:request.ID | Should -Be 'qos-01'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 256
        $script:request.ASSOCIATEOBJIDLIST | Should -Be @('lg-01')
    }

    It 'associates a host with type 21' {
        $null = Add-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -HostName 'esx01' -Confirm:$false

        $script:request.ASSOCIATEOBJTYPE | Should -Be 21
        $script:request.ASSOCIATEOBJIDLIST | Should -Be @('host-01')
    }

    It 'associates a vStore with type 16442' {
        $null = Add-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -VstoreName 'vstore01' -Confirm:$false

        $script:request.ASSOCIATEOBJTYPE | Should -Be 16442
        $script:request.ASSOCIATEOBJIDLIST | Should -Be @('vs-01')
    }

    It 'associates a child policy with type 230' {
        $null = Add-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -ChildPolicyName 'qos01-child' -Confirm:$false

        $script:request.ASSOCIATEOBJTYPE | Should -Be 230
        $script:request.ASSOCIATEOBJIDLIST | Should -Be @('qos-02')
    }

    It 'rejects when no target parameter is specified' {
        { Add-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*exactly one of*'
    }

    It 'rejects when more than one target parameter is specified' {
        { Add-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -HostName 'esx01' -VstoreName 'vstore01' -Confirm:$false -ErrorAction Stop } |
            Should -Throw '*exactly one of*'
    }

    It 'removes a LUN group association via remove_associate' {
        $null = Remove-DMQosAssociation -WebSession $script:session -Name 'qos01-parent' -LunGroupName 'production-luns' -Confirm:$false

        $script:resource | Should -Be 'ioclass/remove_associate'
        $script:request.ASSOCIATEOBJTYPE | Should -Be 256
        $script:request.ASSOCIATEOBJIDLIST | Should -Be @('lg-01')
    }
}
}
