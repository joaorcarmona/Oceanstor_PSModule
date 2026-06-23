BeforeAll {
    function global:Get-DMSystem {}
    function global:Get-DMHostLink {}
    function global:Connect-deviceManager {}
    function global:Get-DMlun {}
    function global:Get-DMlunGroup {}
    function global:Get-DMdisk {}
    function global:Get-DMhost {}
    function global:Get-DMhostGroup {}
    function global:Get-DMstoragePool {}
    function global:Get-DMvStore {}
    function global:Get-DMFileSystem {}
    function global:Get-DMShare {}
    function global:Get-DMAlarm {}
    function global:Get-DMEnclosure {}
    function global:Get-DMController {}
    function global:Get-DMInterfaceModule {}

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorViewHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorViewStorage.ps1"
}

AfterAll {
    @(
        'Get-DMSystem', 'Get-DMHostLink', 'Connect-deviceManager', 'Get-DMlun',
        'Get-DMlunGroup', 'Get-DMdisk', 'Get-DMhost', 'Get-DMhostGroup',
        'Get-DMstoragePool', 'Get-DMvStore', 'Get-DMFileSystem', 'Get-DMShare',
        'Get-DMAlarm', 'Get-DMEnclosure', 'Get-DMController', 'Get-DMInterfaceModule'
    ) | ForEach-Object {
        Remove-Item -LiteralPath "Function:\global:$_" -ErrorAction SilentlyContinue
    }
}

Describe 'Session and view classes' {
    It 'creates a session and resolves the system version' {
        Mock Get-DMSystem {
            [pscustomobject]@{ version = 'V600R001' }
        }
        $logon = [pscustomobject]@{ data = [pscustomobject]@{ deviceid = 'device-01'; iBaseToken = 'token-01' } }
        $headers = @{ iBaseToken = 'token-01' }
        $webRequestSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

        $result = New-Object -TypeName OceanstorSession -ArgumentList @($logon, $headers, $webRequestSession, 'oceanstor.test')

        $result.DeviceId | Should -Be 'device-01'
        $result.Hostname | Should -Be 'oceanstor.test'
        $result.Version | Should -Be 'V600R001'
        Should -Invoke Get-DMSystem -Times 1 -Exactly
    }

    It 'creates a host view with retrieved paths' {
        Mock Get-DMHostLink {
            @([pscustomobject]@{ Id = 'path-01' })
        }
        $session = [pscustomobject]@{ DeviceId = 'device-01' }
        $hostRecord = [pscustomobject]@{ Id = 'host-01' }

        $result = New-Object -TypeName OceanStorViewHost -ArgumentList @($hostRecord, $session)

        $result.Properties.Id | Should -Be 'host-01'
        $result.Paths[0].Id | Should -Be 'path-01'
        $result.Session | Should -Be $session
        Should -Invoke Get-DMHostLink -Times 1 -Exactly
    }

    It 'assembles a storage view from device manager queries' {
        $connection = [pscustomobject]@{ DeviceId = 'device-01' }
        Mock Connect-deviceManager { $connection }
        Mock Get-DMSystem { [pscustomobject]@{ sn = 'system-01' } }
        Mock Get-DMlun { @('lun-01') }
        Mock Get-DMlunGroup { @('lungroup-01') }
        Mock Get-DMdisk { @('disk-01') }
        Mock Get-DMhost { @('host-01') }
        Mock Get-DMhostGroup { @('hostgroup-01') }
        Mock Get-DMstoragePool { @('pool-01') }
        Mock Get-DMvStore { @('vstore-01') }
        Mock Get-DMFileSystem { @('fs-01') }
        Mock Get-DMShare { @('share-01') }
        Mock Get-DMAlarm { @('alarm-01') }
        Mock Get-DMEnclosure { @('enclosure-01') }
        Mock Get-DMController { @('controller-01') }
        Mock Get-DMInterfaceModule { @('module-01') }

        $result = New-Object -TypeName OceanstorViewStorage -ArgumentList 'oceanstor.test'

        $result.Hostname | Should -Be 'oceanstor.test'
        $result.DeviceId | Should -Be 'system-01'
        $result.Luns | Should -Contain 'lun-01'
        $result.Controllers | Should -Contain 'controller-01'
        $result.Session | Should -Be $connection
        Should -Invoke Connect-deviceManager -Times 1 -Exactly
        Should -Invoke Get-DMShare -Times 2 -Exactly
    }
}
