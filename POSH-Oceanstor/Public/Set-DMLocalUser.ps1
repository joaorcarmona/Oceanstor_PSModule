function Set-DMLocalUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Description,
        [object]$Password,
        [object]$OldPassword,
        [string]$RoleId,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    if ($Description) { $body.DESCRIPTION = $Description }
    if ($Password) { $body.PASSWORD = ConvertFrom-DMSensitiveValue -Value $Password }
    if ($OldPassword) { $body.OLDPASSWORD = ConvertFrom-DMSensitiveValue -Value $OldPassword }
    if ($RoleId) { $body.roleId = $RoleId }

    $encodedId = [uri]::EscapeDataString($Id)
    if ($PSCmdlet.ShouldProcess($Id, 'Modify local user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "user/$encodedId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
