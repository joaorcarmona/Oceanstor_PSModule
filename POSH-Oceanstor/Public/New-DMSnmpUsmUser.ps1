function New-DMSnmpUsmUser {
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

    if ($PSCmdlet.ShouldProcess($Name, 'Create SNMP USM user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'snmp_usm' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
