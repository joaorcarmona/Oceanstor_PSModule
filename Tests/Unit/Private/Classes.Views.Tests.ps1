BeforeAll {
    function global:Get-DMSystem {}
    function global:Get-DMHostLinks {}
    function global:Connect-deviceManager {}
    function global:Get-DMluns {}
    function global:Get-DMlunGroups {}
    function global:Get-DMdisks {}
    function global:Get-DMhosts {}
    function global:Get-DMhostGroups {}
    function global:Get-DMstoragePools {}
    function global:Get-DMvStore {}
    function global:Get-DMFileSystem {}
    function global:Get-DMShares {}
    function global:Get-DMAlarms {}
    function global:Get-DMEnclosures {}
    function global:Get-DMControllers {}
    function global:Get-DMInterfaceModules {}

    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorViewHost.ps1"
    . "$PSScriptRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorViewStorage.ps1"
}

AfterAll {
    @(
        'Get-DMSystem', 'Get-DMHostLinks', 'Connect-deviceManager', 'Get-DMluns',
        'Get-DMlunGroups', 'Get-DMdisks', 'Get-DMhosts', 'Get-DMhostGroups',
        'Get-DMstoragePools', 'Get-DMvStore', 'Get-DMFileSystem', 'Get-DMShares',
        'Get-DMAlarms', 'Get-DMEnclosures', 'Get-DMControllers', 'Get-DMInterfaceModules'
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
        Mock Get-DMHostLinks {
            @([pscustomobject]@{ Id = 'path-01' })
        }
        $session = [pscustomobject]@{ DeviceId = 'device-01' }
        $hostRecord = [pscustomobject]@{ Id = 'host-01' }

        $result = New-Object -TypeName OceanStorViewHost -ArgumentList @($hostRecord, $session)

        $result.Properties.Id | Should -Be 'host-01'
        $result.Paths[0].Id | Should -Be 'path-01'
        $result.Session | Should -Be $session
        Should -Invoke Get-DMHostLinks -Times 1 -Exactly
    }

    It 'assembles a storage view from device manager queries' {
        $connection = [pscustomobject]@{ DeviceId = 'device-01' }
        Mock Connect-deviceManager { $connection }
        Mock Get-DMSystem { [pscustomobject]@{ sn = 'system-01' } }
        Mock Get-DMluns { @('lun-01') }
        Mock Get-DMlunGroups { @('lungroup-01') }
        Mock Get-DMdisks { @('disk-01') }
        Mock Get-DMhosts { @('host-01') }
        Mock Get-DMhostGroups { @('hostgroup-01') }
        Mock Get-DMstoragePools { @('pool-01') }
        Mock Get-DMvStore { @('vstore-01') }
        Mock Get-DMFileSystem { @('fs-01') }
        Mock Get-DMShares { @('share-01') }
        Mock Get-DMAlarms { @('alarm-01') }
        Mock Get-DMEnclosures { @('enclosure-01') }
        Mock Get-DMControllers { @('controller-01') }
        Mock Get-DMInterfaceModules { @('module-01') }

        $result = New-Object -TypeName OceanstorViewStorage -ArgumentList 'oceanstor.test'

        $result.Hostname | Should -Be 'oceanstor.test'
        $result.DeviceId | Should -Be 'system-01'
        $result.Luns | Should -Contain 'lun-01'
        $result.Controllers | Should -Contain 'controller-01'
        $result.Session | Should -Be $connection
        Should -Invoke Connect-deviceManager -Times 1 -Exactly
        Should -Invoke Get-DMShares -Times 2 -Exactly
    }
}
