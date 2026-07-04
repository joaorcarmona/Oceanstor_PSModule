function New-DMRole {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Description,
        [Parameter(Mandatory = $true)][string]$RoleOwnerGroup,
        [string]$RoleSource,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    $body.name = $Name
    $body.roleOwnerGroup = $RoleOwnerGroup
    if ($Description) { $body.description = $Description }
    if ($RoleSource) { $body.roleSource = $RoleSource }

    if ($PSCmdlet.ShouldProcess($Name, 'Create role')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'role' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
