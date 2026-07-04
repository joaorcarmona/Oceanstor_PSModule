function New-DMLocalUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][object]$Password,
        [string]$Description,
        [string]$RoleId,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    $body.NAME = $Name
    $body.PASSWORD = ConvertFrom-DMSensitiveValue -Value $Password
    if ($Description) { $body.DESCRIPTION = $Description }
    if ($RoleId) { $body.roleId = $RoleId }

    if ($PSCmdlet.ShouldProcess($Name, 'Create local user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'user' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
