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
    # The modify interface (PUT role/{id}, OceanStor Dorado 6.1.6 REST reference
    # 4.3.6.3.1) marks id as a Mandatory body field (lowercase, matching the role
    # interface's field casing); name/description are Optional. The doc's terse example
    # omits id, but the Parameters table is the contract, so echo it in the body as
    # well as the URL path to avoid an error-50331651 rejection.
    $body.id = $Id
    if ($Name) { $body.name = $Name }
    if ($Description) { $body.description = $Description }
    $encodedId = [uri]::EscapeDataString($Id)

    if ($PSCmdlet.ShouldProcess($Id, 'Modify role')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "role/$encodedId" -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
