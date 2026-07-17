function New-DMRole {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$Description,
        [Parameter(Mandatory = $true)][string]$RoleOwnerGroup,
        [string]$RoleSource,
        [string]$PermitList,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    # Create-role body per REST reference section 4.3.6.1.1: name and roleOwnerGroup are
    # mandatory; description and permitList are optional. roleSource is a response-only
    # field (it is not accepted on the create interface), so it is only sent when the
    # caller explicitly supplies -RoleSource for compatibility with older behavior.
    $body = @{} + $Property
    $body.name = $Name
    $body.roleOwnerGroup = $RoleOwnerGroup
    if ($Description) { $body.description = $Description }
    if ($PermitList) { $body.permitList = $PermitList }
    if ($RoleSource) { $body.roleSource = $RoleSource }

    if ($PSCmdlet.ShouldProcess($Name, 'Create role')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'role' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
