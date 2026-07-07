function Set-DMSnmpUsmUser {
    # SNMPv3 USM has a two-secret model (auth + privacy passphrases) plus a USM user
    # name; this does not map to a single [PSCredential] (one username / one password).
    # SecureString input is already supported via ConvertFrom-DMSensitiveValue and secret
    # values are never printed or logged, so the plaintext-capable [object] shape is
    # intentional and safe. Redesigning to SecureString-only would be a breaking public
    # contract change. See RELEASE_NOTES / docs/system-management for the recorded decision.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingUsernameAndPasswordParams', '',
        Justification = 'SNMPv3 USM uses two separate passphrases and a user name, which cannot be expressed as a single PSCredential; SecureString input is already accepted and secrets are never exposed.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '',
        Justification = 'Auth/privacy passphrases accept [SecureString] and are normalized via ConvertFrom-DMSensitiveValue; plaintext is also accepted for compatibility and secrets are never printed or logged.')]
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$AuthProtocol,
        [object]$AuthPassword,
        [string]$PrivacyProtocol,
        [object]$PrivacyPassword,
        [uint16]$UserLevel,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    $body.CMO_USM_USER = $Name
    if ($AuthProtocol) { $body.CMO_USM_AUTH_PROT = $AuthProtocol }
    if ($AuthPassword) { $body.CMO_USM_PASSWD = ConvertFrom-DMSensitiveValue -Value $AuthPassword }
    if ($PrivacyProtocol) { $body.CMO_USM_PRIV_PROT = $PrivacyProtocol }
    if ($PrivacyPassword) { $body.CMO_USM_PRIV_PASSWD = ConvertFrom-DMSensitiveValue -Value $PrivacyPassword }
    if ($PSBoundParameters.ContainsKey('UserLevel')) { $body.CMO_USM_USER_LEVEL = "$UserLevel" }

    if ($PSCmdlet.ShouldProcess($Name, 'Modify SNMP USM user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'snmp_usm' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
