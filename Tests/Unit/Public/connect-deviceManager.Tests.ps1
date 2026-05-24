BeforeDiscovery {
    $script:testModule = New-Module -Name ConnectDeviceManagerTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function get-DMSystem {}
        function write-DMError {}

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanstorSession.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Public\connect-deviceManager.ps1"

        Export-ModuleMember -Function connect-deviceManager
    }

    Import-Module $script:testModule -Force
}

AfterAll {
    Remove-Module -Name ConnectDeviceManagerTestModule -Force -ErrorAction SilentlyContinue
    Remove-Variable -Name deviceManager -Scope Global -ErrorAction SilentlyContinue
}

InModuleScope ConnectDeviceManagerTestModule {
Describe 'connect-deviceManager' {
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

        Mock get-DMSystem {
            return [pscustomobject]@{ version = 'V600R001' }
        }
    }

    It 'creates and returns a connection using secure credentials' {
        $securePassword = ConvertTo-SecureString -String 'secure-pass' -AsPlainText -Force
        $script:credential = [pscredential]::new('secure-user', $securePassword)
        Mock Get-Credential { return $script:credential }

        $result = connect-deviceManager -Hostname 'oceanstor.test' -Return $true -Secure

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

    It 'creates a connection using unsecure credential parameters' {
        $result = connect-deviceManager -Hostname 'oceanstor.test' -Return $true -Unsecure -LoginUser 'api-user' -LoginPwd 'api-pass'

        $result.GetType().Name | Should -Be 'OceanstorSession'
        $result.Headers.Authorization | Should -Be 'Basic YXBpLXVzZXI6YXBpLXBhc3M='
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            ($Body | ConvertFrom-Json).username -eq 'api-user' -and
            ($Body | ConvertFrom-Json).password -eq 'api-pass' -and
            ($Body | ConvertFrom-Json).scope -eq 0
        }
    }

    It 'stores the connection in the global deviceManager variable by default' {
        $null = connect-deviceManager -Hostname 'oceanstor.test' -Unsecure -LoginUser 'api-user' -LoginPwd 'api-pass'

        $global:deviceManager.GetType().Name | Should -Be 'OceanstorSession'
        $global:deviceManager.DeviceId | Should -Be 'device-01'
    }
}
}
