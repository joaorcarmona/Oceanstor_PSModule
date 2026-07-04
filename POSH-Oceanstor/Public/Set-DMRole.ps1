function Set-DMRole {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$Name,
        [string]$Description,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    if ($Name) { $body.name = $Name }
    if ($Description) { $body.description = $Description }
    $encodedId = [uri]::EscapeDataString($Id)

    if ($PSCmdlet.ShouldProcess($Id, 'Modify role')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "role/$encodedId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
