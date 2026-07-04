function Remove-DMRole {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Id,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{} + $Property
    if (-not $body.ContainsKey('ID')) { $body.ID = $Id }
    if ($PSCmdlet.ShouldProcess($Id, 'Remove role')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'role' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
