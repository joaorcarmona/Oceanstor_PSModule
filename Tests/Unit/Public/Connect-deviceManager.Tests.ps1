BeforeDiscovery {
    $script:testModule = New-Module -Name ConnectDeviceManagerTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Write-DMError { param($SessionError) }
        # Plain stub: Get-DMSystem is now called by Connect-deviceManager itself
        # (a regular function call, not from inside the class constructor), so
        # the Pester mock below intercepts it reliably on every platform.
        function Get-DMSystem { param($WebSession) }
        function Disconnect-deviceManager { param([pscustomobject]$WebSession) }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Connect-deviceManager.ps1"

        Export-ModuleMember -Function Connect-deviceManager, Get-DMSystem, Disconnect-deviceManager
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name ConnectDeviceManagerTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope ConnectDeviceManagerTestModule {
Describe 'Connect-deviceManager' {
    BeforeEach {
        $script:CurrentOceanstorSession = $null

        $script:logonResponse = [pscustomobject]@{
            error = [pscustomobject]@{ code = 0 }
            data  = [pscustomobject]@{
                deviceid   = 'device-01'
                iBaseToken = 'token-01'
            }
        }

        Mock Invoke-RestMethod {
            return $script:logonResponse
        }

        Mock Get-Credential {
            throw 'Unexpected credential prompt.'
        }

        Mock Get-DMSystem {
            return [pscustomobject]@{ version = 'V600R001' }
        }
    }

    It 'creates and returns a connection by prompting for credentials by default' {
        $securePassword = ConvertTo-SecureString -String 'secure-pass' -AsPlainText -Force
        $script:credential = [pscredential]::new('secure-user', $securePassword)
        Mock Get-Credential { return $script:credential }

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -PassThru

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Hostname | Should -Be 'oceanstor.test'
        $result.DeviceId | Should -Be 'device-01'
        $result.Version | Should -Be 'V600R001'
        $result.Headers.ContainsKey('Authorization') | Should -BeFalse
        $result.Headers.iBaseToken | Should -Be 'token-01'
        Should -Invoke Get-Credential -Times 1 -Exactly
        Should -Invoke Get-DMSystem -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'Post' -and
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/xxxxx/sessions' -and
            -not $SkipCertificateCheck -and
            ($Body | ConvertFrom-Json).username -eq 'secure-user' -and
            ($Body | ConvertFrom-Json).password -eq 'secure-pass'
        }
    }

    It 'keeps the Secure switch as a credential-prompt compatibility path' {
        $securePassword = ConvertTo-SecureString -String 'secure-pass' -AsPlainText -Force
        Mock Get-Credential { return [pscredential]::new('secure-user', $securePassword) }

        $null = Connect-deviceManager -Hostname 'oceanstor.test' -PassThru -Secure

        Should -Invoke Get-Credential -Times 1 -Exactly
    }

    It 'creates a connection using a PSCredential for unattended operation' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -PassThru -Credential $credential

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Headers.ContainsKey('Authorization') | Should -BeFalse
        Should -Invoke Get-Credential -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            ($Body | ConvertFrom-Json).username -eq 'api-user' -and
            ($Body | ConvertFrom-Json).password -eq 'api-pass' -and
            ($Body | ConvertFrom-Json).scope -eq 0 -and
            -not $SkipCertificateCheck
        }
    }

    It 'records and uses SkipCertificateCheck only when explicitly requested' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -PassThru -Credential $credential -SkipCertificateCheck

        $result.SkipCertificateCheck | Should -BeTrue
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $SkipCertificateCheck
        }
    }

    It 'creates a connection using a SecureString password' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -PassThru -LoginUser 'api-user' -LoginPwd $securePassword

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Headers.ContainsKey('Authorization') | Should -BeFalse
        Should -Invoke Get-Credential -Times 0 -Exactly
    }

    It 'accepts the legacy -Return alias for backward compatibility' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -Return -Credential $credential

        $result.GetType().Name | Should -Be 'OceanstorSession'
    }

    It 'stores the connection in the module-scoped CurrentOceanstorSession variable by default' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $null = Connect-deviceManager -Hostname 'oceanstor.test' -Credential $credential

        $script:CurrentOceanstorSession.GetType().Name | Should -Be 'OceanstorSession'
        $script:CurrentOceanstorSession.DeviceId | Should -Be 'device-01'
        $script:CurrentOceanstorSession.SkipCertificateCheck | Should -BeFalse
    }

    It 'closes the previous cached session before replacing it' {
        $script:previousSession = [pscustomobject]@{ Hostname = 'previous.test' }
        $script:CurrentOceanstorSession = $script:previousSession
        Mock Disconnect-deviceManager { }

        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $null = Connect-deviceManager -Hostname 'oceanstor.test' -Credential $credential

        Should -Invoke Disconnect-deviceManager -Times 1 -Exactly -ParameterFilter {
            $WebSession -eq $script:previousSession
        }
        $script:CurrentOceanstorSession.Hostname | Should -Be 'oceanstor.test'
    }

    It 'still replaces the cached session when closing the previous one fails' {
        $script:CurrentOceanstorSession = [pscustomobject]@{ Hostname = 'previous.test' }
        Mock Disconnect-deviceManager { throw 'previous session already expired' }

        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        { Connect-deviceManager -Hostname 'oceanstor.test' -Credential $credential } | Should -Not -Throw

        $script:CurrentOceanstorSession.Hostname | Should -Be 'oceanstor.test'
    }

    It 'does not attempt to close a session when none exists yet' {
        Mock Disconnect-deviceManager { }

        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $null = Connect-deviceManager -Hostname 'oceanstor.test' -Credential $credential

        Should -Invoke Disconnect-deviceManager -Times 0 -Exactly
    }
}
}
