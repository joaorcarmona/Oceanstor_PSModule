function New-DMLocalUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Password,
        [string]$Description,
        [string]$RoleId,
        # User type per REST reference (Creating a User): 0 = local user (default),
        # 1 = LDAP user, 2 = LDAP group, 8 = RADIUS user. SCOPE is a mandatory body field.
        [string]$Scope = '0',
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    $body.NAME = $Name
    $body.PASSWORD = ConvertFrom-DMSensitiveValue -Value $Password
    $body.SCOPE = $Scope
    if ($Description) { $body.DESCRIPTION = $Description }
    # The role field is ROLEID (uppercase) on the create interface; a camel-case
    # roleId is silently ignored and the mandatory-field check fails with 50331651.
    if ($RoleId) { $body.ROLEID = $RoleId }

    if ($PSCmdlet.ShouldProcess($Name, 'Create local user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'user' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
