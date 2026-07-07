class OceanStorCertificate {
    [string]$CertificateType
    [int]$TypeId
    [string]$Status
    [string]$Subject
    [string]$Issuer
    [nullable[datetime]]$ValidTo
    [string]$Fingerprint
    [string]$SerialNumber
    [string]$SignatureAlgorithm
    [string]$KeyAlgorithm
    [int]$KeyLength
    [int]$ExpireWarningDays
    [string]$Usage
    [string]$SubjectCommonName
    [string]$SubjectAlternativeName
    [bool]$AutoUpdateSupported
    [bool]$AutoUpdateEnabled
    [string]$CAStatus
    [string]$CASubject
    [string]$CAIssuer
    [nullable[datetime]]$CAValidTo
    [string]$CAFingerprint
    [string]$CASerialNumber
    [string]$CAKeyAlgorithm
    [int]$CAKeyLength
    [string]$CASignatureAlgorithm
    [string]$VstoreId
    hidden [pscustomobject]$Raw

    OceanStorCertificate ([object]$certificateReceived) {
        $this.Raw = $certificateReceived
        $this.TypeId = [OceanStorCertificate]::ToInt($certificateReceived.CERTIFICATE_TYPE)
        $this.CertificateType = [OceanStorCertificate]::TypeName($certificateReceived.CERTIFICATE_TYPE)
        $this.Status = [OceanStorCertificate]::StatusName($certificateReceived.CERTIFICATE_STATUS)
        $this.Subject = [OceanStorCertificate]::CleanText($certificateReceived.CERTIFICATE_SUBJECT)
        $this.Issuer = [OceanStorCertificate]::CleanText($certificateReceived.CERTIFICATE_ISSUER)
        $this.ValidTo = [OceanStorCertificate]::ParseDate($certificateReceived.CERTIFICATE_EXPIRE_TIME)
        $this.Fingerprint = [OceanStorCertificate]::CleanText($certificateReceived.CERTIFICATE_FINGERPRINT)
        $this.SerialNumber = [OceanStorCertificate]::CleanText($certificateReceived.certificateSerialNumber)
        $this.SignatureAlgorithm = [OceanStorCertificate]::CleanText($certificateReceived.CERTIFICATE_SIGNATURE_ALGORITHM)
        $this.KeyAlgorithm = [OceanStorCertificate]::KeyAlgorithmName($certificateReceived.KEY_ALGORITHM)
        $this.KeyLength = [OceanStorCertificate]::ToInt($certificateReceived.KEY_LENGTH)
        $this.ExpireWarningDays = [OceanStorCertificate]::ToInt($certificateReceived.CERTIFICATE_EXPIRE_PREWARNING_TIME)
        $this.Usage = [OceanStorCertificate]::CleanText($certificateReceived.USE_OF_CERTIFICATE)
        $this.SubjectCommonName = [OceanStorCertificate]::CleanText($certificateReceived.SUBJECT_COMMON_NAME)
        $this.SubjectAlternativeName = [OceanStorCertificate]::CleanText($certificateReceived.SUBJECT_ALTERNATIVE_NAME)
        $this.AutoUpdateSupported = [OceanStorCertificate]::ToBool($certificateReceived.isSupportAutoUpdate)
        $this.AutoUpdateEnabled = [OceanStorCertificate]::ToBool($certificateReceived.enabledAutoUpdate)
        $this.CAStatus = [OceanStorCertificate]::StatusName($certificateReceived.CA_CERTIFICATE_STATUS)
        $this.CASubject = [OceanStorCertificate]::CleanText($certificateReceived.CA_CERTIFICATE_SUBJECT)
        $this.CAIssuer = [OceanStorCertificate]::CleanText($certificateReceived.CA_CERTIFICATE_ISSUER)
        $this.CAValidTo = [OceanStorCertificate]::ParseDate($certificateReceived.CA_CERTIFICATE_EXPIRE_TIME)
        # Doc 4.3.5.3.1: camelCase certificateFingerPrint is the CA-side fingerprint.
        $this.CAFingerprint = [OceanStorCertificate]::CleanText($certificateReceived.certificateFingerPrint)
        $this.CASerialNumber = [OceanStorCertificate]::CleanText($certificateReceived.caCertificateSerialNumber)
        $this.CAKeyAlgorithm = [OceanStorCertificate]::KeyAlgorithmName($certificateReceived.CA_KEY_ALGORITHM)
        $this.CAKeyLength = [OceanStorCertificate]::ToInt($certificateReceived.CA_KEY_LENGTH)
        $this.CASignatureAlgorithm = [OceanStorCertificate]::CleanText($certificateReceived.CA_CERTIFICATE_SIGNATURE_ALGORITHM)
        $this.VstoreId = [string]$certificateReceived.vstoreId
    }

    hidden static [string] TypeName([object]$value) {
        switch ([string]$value) {
            '0'  { return 'KMC' }
            '2'  { return 'Domain Authentication' }
            '3'  { return 'HyperMetro' }
            '4'  { return 'HTTPS' }
            '5'  { return 'FTPS' }
            '6'  { return 'Syslog' }
            '7'  { return 'NTP' }
            '8'  { return 'Call Home' }
            '14' { return 'DeviceManager' }
            '18' { return 'SSO' }
            '19' { return 'Email' }
            '26' { return 'Disk Authentication' }
            '30' { return 'Email OTP' }
            '38' { return 'File Service Domain Authentication' }
            '63' { return 'CA Server' }
            '65' { return 'SmartContainer' }
            '68' { return 'In-band Management' }
            '70' { return 'S3 Authentication' }
        }
        return [string]$value
    }

    hidden static [string] StatusName([object]$value) {
        switch ([string]$value) {
            '0' { return 'Absent' }    # doc value: "inexistent" / "NOT EXIST"
            '1' { return 'Valid' }
            '2' { return 'Invalid' }
        }
        return [string]$value
    }

    hidden static [string] KeyAlgorithmName([object]$value) {
        switch ([string]$value) {
            '0' { return 'RSA' }
            '1' { return 'ECC' }
            '2' { return 'DSA' }
        }
        return [string]$value
    }

    # The array reports absent values as "--" (and sometimes ""); map to $null/empty.
    hidden static [string] CleanText([object]$value) {
        $text = [string]$value
        if ($text -eq '--') { return '' }
        return $text
    }

    hidden static [nullable[datetime]] ParseDate([object]$value) {
        $text = [string]$value
        if ([string]::IsNullOrWhiteSpace($text) -or $text -eq '--') { return $null }
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($text, 'yyyy-MM-dd', [cultureinfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed
        }
        if ([datetime]::TryParse($text, [cultureinfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) {
            return $parsed
        }
        return $null
    }

    hidden static [bool] ToBool([object]$value) {
        $text = [string]$value
        return ($text -eq 'true' -or $text -eq '1')
    }

    hidden static [int] ToInt([object]$value) {
        $parsed = 0
        if ([int]::TryParse([string]$value, [ref]$parsed)) { return $parsed }
        return 0
    }
}
