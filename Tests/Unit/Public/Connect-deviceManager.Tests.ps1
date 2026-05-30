BeforeDiscovery {
    $script:testModule = New-Module -Name ConnectDeviceManagerTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Get-DMSystem {}
        function Write-DMError {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Connect-deviceManager.ps1"

        Export-ModuleMember -Function Connect-deviceManager
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name ConnectDeviceManagerTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope ConnectDeviceManagerTestModule {
Describe 'Connect-deviceManager' {
    BeforeEach {
        Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue

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

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -Return $true

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Hostname | Should -Be 'oceanstor.test'
        $result.DeviceId | Should -Be 'device-01'
        $result.Headers.Authorization | Should -Be 'Basic c2VjdXJlLXVzZXI6c2VjdXJlLXBhc3M='
        $result.Headers.iBaseToken | Should -Be 'token-01'
        Should -Invoke Get-Credential -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            $Method -eq 'Post' -and
            $Uri -eq 'https://oceanstor.test:8088/deviceManager/rest/xxxxx/sessions' -and
            $SkipCertificateCheck -and
            ($Body | ConvertFrom-Json).username -eq 'secure-user' -and
            ($Body | ConvertFrom-Json).password -eq 'secure-pass'
        }
    }

    It 'keeps the Secure switch as a credential-prompt compatibility path' {
        $securePassword = ConvertTo-SecureString -String 'secure-pass' -AsPlainText -Force
        Mock Get-Credential { return [pscredential]::new('secure-user', $securePassword) }

        $null = Connect-deviceManager -Hostname 'oceanstor.test' -Return $true -Secure

        Should -Invoke Get-Credential -Times 1 -Exactly
    }

    It 'creates a connection using a PSCredential for unattended operation' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -Return $true -Credential $credential

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Headers.Authorization | Should -Be 'Basic YXBpLXVzZXI6YXBpLXBhc3M='
        Should -Invoke Get-Credential -Times 0 -Exactly
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            ($Body | ConvertFrom-Json).username -eq 'api-user' -and
            ($Body | ConvertFrom-Json).password -eq 'api-pass' -and
            ($Body | ConvertFrom-Json).scope -eq 0
        }
    }

    It 'creates a connection using a SecureString password' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force

        $result = Connect-deviceManager -Hostname 'oceanstor.test' -Return $true -LoginUser 'api-user' -LoginPwd $securePassword

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Headers.Authorization | Should -Be 'Basic YXBpLXVzZXI6YXBpLXBhc3M='
        Should -Invoke Get-Credential -Times 0 -Exactly
    }

    It 'stores the connection in the global deviceManager variable by default' {
        $securePassword = ConvertTo-SecureString -String 'api-pass' -AsPlainText -Force
        $credential = [pscredential]::new('api-user', $securePassword)

        $null = Connect-deviceManager -Hostname 'oceanstor.test' -Credential $credential

        $global:deviceManager.GetType().Name | Should -Be 'OceanstorSession'
        $global:deviceManager.DeviceId | Should -Be 'device-01'
    }
}
}
