BeforeDiscovery {
    $script:certificateGetterModule = New-Module -Name CertificateGetterTestModule -ArgumentList $PSScriptRoot -ScriptBlock {
        param($testRoot)

        function Invoke-DeviceManager {
            param(
                [pscustomobject]$WebSession,
                [string]$Method,
                [string]$Resource,
                [hashtable]$BodyData,
                [int]$TimeoutSec,
                [switch]$ApiV2
            )
        }

        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Get-DMApiErrorMessage.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\Select-DMResponseData.ps1"
        . "$testRoot\..\..\..\POSH-Oceanstor\Private\class-OceanStorCertificate.ps1"

        . "$testRoot\..\..\..\POSH-Oceanstor\Public\Get-DMCertificate.ps1"

        Export-ModuleMember -Function 'Get-DMCertificate'
    }

    Import-Module $script:certificateGetterModule -Force
}

AfterAll {
    Remove-Module -Name CertificateGetterTestModule -Force -ErrorAction SilentlyContinue
}

InModuleScope CertificateGetterTestModule {
Describe 'Get-DMCertificate' {
    BeforeEach {
        $script:session = [pscustomobject]@{ version = 'V600R001' }
        $script:resource = $null
        $script:method = $null

        # Mock rows follow the documented GET certificate response schema
        # (REST Interface Reference 4.3.5.3.1): one installed DeviceManager
        # certificate and one empty KMC slot with "--" placeholders.
        $script:installedRow = [pscustomobject]@{
            CERTIFICATE_TYPE                   = '14'
            CERTIFICATE_STATUS                 = '1'
            CERTIFICATE_SUBJECT                = 'C=CN,O=Default,CN=2102353TXP10L8000009_1652849125671770'
            CERTIFICATE_ISSUER                 = 'C=CN,O=Default,CN=2102353TXP10L8000009_1652849125671770'
            CERTIFICATE_EXPIRE_TIME            = '2042-03-03'
            CERTIFICATE_EXPIRE_PREWARNING_TIME = '30'
            CERTIFICATE_FINGERPRINT            = '78:16:7A:3E:1E:4A:05:97:32:9F:80:88:8F:BC:05:92:F7:B8:72:FB'
            CERTIFICATE_SIGNATURE_ALGORITHM    = 'SHA256WITHRSA'
            certificateSerialNumber            = '0'
            KEY_ALGORITHM                      = '0'
            KEY_LENGTH                         = 2048
            USE_OF_CERTIFICATE                 = ''
            SUBJECT_COMMON_NAME                = ''
            SUBJECT_ALTERNATIVE_NAME           = ''
            isSupportAutoUpdate                = 'true'
            enabledAutoUpdate                  = '0'
            CA_CERTIFICATE_STATUS              = '1'
            CA_CERTIFICATE_SUBJECT             = 'C=CN,O=Huawei,CN=Huawei Equipment CA'
            CA_CERTIFICATE_ISSUER              = 'C=CN,O=Huawei,CN=Huawei Equipment CA'
            CA_CERTIFICATE_EXPIRE_TIME         = '2041-10-12'
            CA_CERTIFICATE_SIGNATURE_ALGORITHM = 'SHA256WITHRSA'
            certificateFingerPrint             = 'AA:BB:CC:DD'
            caCertificateSerialNumber          = '570A119742C4E3CC'
            CA_KEY_ALGORITHM                   = '0'
            CA_KEY_LENGTH                      = 4096
            validPeriod                        = '0'
            vstoreId                           = '0'
        }
        $script:emptyRow = [pscustomobject]@{
            CERTIFICATE_TYPE                   = '0'
            CERTIFICATE_STATUS                 = '0'
            CERTIFICATE_SUBJECT                = '--'
            CERTIFICATE_ISSUER                 = '--'
            CERTIFICATE_EXPIRE_TIME            = '--'
            CERTIFICATE_EXPIRE_PREWARNING_TIME = '30'
            CERTIFICATE_FINGERPRINT            = '--'
            CERTIFICATE_SIGNATURE_ALGORITHM    = '--'
            certificateSerialNumber            = '--'
            KEY_ALGORITHM                      = '0'
            KEY_LENGTH                         = 0
            USE_OF_CERTIFICATE                 = '--'
            SUBJECT_COMMON_NAME                = ''
            SUBJECT_ALTERNATIVE_NAME           = ''
            isSupportAutoUpdate                = 'false'
            enabledAutoUpdate                  = '0'
            CA_CERTIFICATE_STATUS              = '0'
            CA_CERTIFICATE_SUBJECT             = '--'
            CA_CERTIFICATE_ISSUER              = '--'
            CA_CERTIFICATE_EXPIRE_TIME         = '--'
            CA_CERTIFICATE_SIGNATURE_ALGORITHM = '--'
            certificateFingerPrint             = '--'
            caCertificateSerialNumber          = '--'
            CA_KEY_ALGORITHM                   = '0'
            CA_KEY_LENGTH                      = 0
            validPeriod                        = '0'
            vstoreId                           = '0'
        }

        Mock Invoke-DeviceManager {
            $script:method = $Method
            $script:resource = $Resource
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = @($script:installedRow, $script:emptyRow)
            }
        }
    }

    It 'queries the documented read-only certificate resource with GET' {
        Get-DMCertificate -WebSession $script:session | Out-Null

        $script:method | Should -Be 'GET'
        $script:resource | Should -Be 'certificate'
        Should -Invoke Invoke-DeviceManager -Times 1 -Exactly
    }

    It 'appends the documented vstoreId filter when -VstoreId is passed' {
        Get-DMCertificate -WebSession $script:session -VstoreId '3' | Out-Null

        $script:resource | Should -Be 'certificate?vstoreId=3'
    }

    It 'returns typed OceanStorCertificate objects' {
        $result = Get-DMCertificate -WebSession $script:session

        $result.Count | Should -Be 2
        $result | ForEach-Object { $_.GetType().Name | Should -Be 'OceanStorCertificate' }
    }

    It 'declares string-form OutputType OceanStorCertificate' {
        (Get-Command Get-DMCertificate).OutputType.Name | Should -Contain 'OceanStorCertificate'
    }

    It 'maps documented fields for an installed certificate' {
        $cert = (Get-DMCertificate -WebSession $script:session)[0]

        $cert.CertificateType | Should -Be 'DeviceManager'
        $cert.TypeId | Should -Be 14
        $cert.Status | Should -Be 'Valid'
        $cert.Subject | Should -Be 'C=CN,O=Default,CN=2102353TXP10L8000009_1652849125671770'
        $cert.Issuer | Should -Be 'C=CN,O=Default,CN=2102353TXP10L8000009_1652849125671770'
        $cert.ValidTo | Should -Be ([datetime]::new(2042, 3, 3))
        $cert.Fingerprint | Should -Be '78:16:7A:3E:1E:4A:05:97:32:9F:80:88:8F:BC:05:92:F7:B8:72:FB'
        $cert.SerialNumber | Should -Be '0'
        $cert.SignatureAlgorithm | Should -Be 'SHA256WITHRSA'
        $cert.KeyAlgorithm | Should -Be 'RSA'
        $cert.KeyLength | Should -Be 2048
        $cert.ExpireWarningDays | Should -Be 30
        $cert.AutoUpdateSupported | Should -BeTrue
        $cert.AutoUpdateEnabled | Should -BeFalse
        $cert.CAStatus | Should -Be 'Valid'
        $cert.CAIssuer | Should -Be 'C=CN,O=Huawei,CN=Huawei Equipment CA'
        $cert.CAValidTo | Should -Be ([datetime]::new(2041, 10, 12))
        $cert.CAFingerprint | Should -Be 'AA:BB:CC:DD'
        $cert.CASerialNumber | Should -Be '570A119742C4E3CC'
        $cert.CAKeyLength | Should -Be 4096
        $cert.VstoreId | Should -Be '0'
    }

    It 'normalizes "--" placeholders on empty certificate slots' {
        $cert = (Get-DMCertificate -WebSession $script:session)[1]

        $cert.CertificateType | Should -Be 'KMC'
        $cert.Status | Should -Be 'Absent'
        $cert.Subject | Should -Be ''
        $cert.Issuer | Should -Be ''
        $cert.ValidTo | Should -BeNullOrEmpty
        $cert.Fingerprint | Should -Be ''
        $cert.SerialNumber | Should -Be ''
        $cert.CAStatus | Should -Be 'Absent'
        $cert.CAValidTo | Should -BeNullOrEmpty
    }

    It 'handles an empty inventory safely' {
        Mock Invoke-DeviceManager {
            [pscustomobject]@{
                error = [pscustomobject]@{ Code = 0 }
                data  = @()
            }
        }

        $result = Get-DMCertificate -WebSession $script:session

        @($result).Count | Should -Be 0
    }

    It 'limits the default display to non-sensitive summary properties' {
        $cert = (Get-DMCertificate -WebSession $script:session)[0]

        $displaySet = $cert.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames
        $displaySet | Should -Be @('CertificateType', 'Status', 'Subject', 'Issuer', 'ValidTo')
        $displaySet | Should -Not -Contain 'Raw'
    }

    It 'keeps the raw response row hidden from default member listings' {
        $cert = (Get-DMCertificate -WebSession $script:session)[0]

        $cert | Get-Member -Name Raw -MemberType Properties | Should -BeNullOrEmpty
        # Still reachable explicitly for troubleshooting, and contains no
        # private-key material by schema (fingerprints/subjects/dates only).
        $cert.Raw.CERTIFICATE_TYPE | Should -Be '14'
    }

    It 'never exposes private-key material properties' {
        $cert = (Get-DMCertificate -WebSession $script:session)[0]

        $propertyNames = @($cert | Get-Member -MemberType Properties | ForEach-Object Name)
        $propertyNames | Should -Not -Contain 'PrivateKey'
        $propertyNames -match 'ENCRYPT' | Should -BeNullOrEmpty
    }

    It 'is registered for read-only live validation' {
        $readValidation = Get-Content -LiteralPath "$PSScriptRoot\..\..\Integration\Private\ReadValidation.ps1" -Raw

        $readValidation | Should -Match "Add-ValidationResult -Name 'Get-DMCertificate' -ExpectedType 'OceanStorCertificate'"
    }
}
}
