BeforeAll {
    function global:get-DMSystem {}
    function global:get-DMHostLinks {}
    function global:connect-deviceManager {}
    function global:get-DMluns {}
    function global:get-DMlunGroups {}
    function global:get-DMdisks {}
    function global:get-DMhosts {}
    function global:get-DMhostGroups {}
    function global:get-DMstoragePools {}
    function global:get-DMvStore {}
    function global:get-DMFileSystem {}
    function global:get-DMShares {}
    function global:get-DMAlarms {}
    function global:get-DMEnclosures {}
    function global:get-DMControllers {}
    function global:get-DMInterfaceModules {}

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorViewHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorViewStorage.ps1"
}

AfterAll {
    @(
        'get-DMSystem', 'get-DMHostLinks', 'connect-deviceManager', 'get-DMluns',
        'get-DMlunGroups', 'get-DMdisks', 'get-DMhosts', 'get-DMhostGroups',
        'get-DMstoragePools', 'get-DMvStore', 'get-DMFileSystem', 'get-DMShares',
        'get-DMAlarms', 'get-DMEnclosures', 'get-DMControllers', 'get-DMInterfaceModules'
    ) | ForEach-Object {
        Remove-Item -LiteralPath "Function:\global:$_" -ErrorAction SilentlyContinue
    }
}

Describe 'Session and view classes' {
    It 'creates a session and resolves the system version' {
        Mock get-DMSystem {
            [pscustomobject]@{ version = 'V600R001' }
        }
        $logon = [pscustomobject]@{ data = [pscustomobject]@{ deviceid = 'device-01'; iBaseToken = 'token-01' } }
        $headers = @{ iBaseToken = 'token-01' }
        $webRequestSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()

        $result = New-Object -TypeName OceanstorSession -ArgumentList @($logon, $headers, $webRequestSession, 'oceanstor.test')

        $result.DeviceId | Should -Be 'device-01'
        $result.Hostname | Should -Be 'oceanstor.test'
        $result.Version | Should -Be 'V600R001'
        Should -Invoke get-DMSystem -Times 1 -Exactly
    }

    It 'creates a host view with retrieved paths' {
        Mock get-DMHostLinks {
            @([pscustomobject]@{ Id = 'path-01' })
        }
        $session = [pscustomobject]@{ DeviceId = 'device-01' }
        $hostRecord = [pscustomobject]@{ Id = 'host-01' }

        $result = New-Object -TypeName OceanStorViewHost -ArgumentList @($hostRecord, $session)

        $result.Properties.Id | Should -Be 'host-01'
        $result.Paths[0].Id | Should -Be 'path-01'
        Should -Invoke get-DMHostLinks -Times 1 -Exactly
    }

    It 'assembles a storage view from device manager queries' {
        $connection = [pscustomobject]@{ DeviceId = 'device-01' }
        Mock connect-deviceManager { $connection }
        Mock get-DMSystem { [pscustomobject]@{ sn = 'system-01' } }
        Mock get-DMluns { @('lun-01') }
        Mock get-DMlunGroups { @('lungroup-01') }
        Mock get-DMdisks { @('disk-01') }
        Mock get-DMhosts { @('host-01') }
        Mock get-DMhostGroups { @('hostgroup-01') }
        Mock get-DMstoragePools { @('pool-01') }
        Mock get-DMvStore { @('vstore-01') }
        Mock get-DMFileSystem { @('fs-01') }
        Mock get-DMShares { @('share-01') }
        Mock get-DMAlarms { @('alarm-01') }
        Mock get-DMEnclosures { @('enclosure-01') }
        Mock get-DMControllers { @('controller-01') }
        Mock get-DMInterfaceModules { @('module-01') }

        $result = New-Object -TypeName OceanstorViewStorage -ArgumentList 'oceanstor.test'

        $result.Hostname | Should -Be 'oceanstor.test'
        $result.DeviceId | Should -Be 'system-01'
        $result.Luns | Should -Contain 'lun-01'
        $result.Controllers | Should -Contain 'controller-01'
        Should -Invoke connect-deviceManager -Times 1 -Exactly
        Should -Invoke get-DMShares -Times 2 -Exactly
    }
}
