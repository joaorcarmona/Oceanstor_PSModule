function Remove-DMLocalUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Id
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $encodedId = [uri]::EscapeDataString($Id)
    if ($PSCmdlet.ShouldProcess($Id, 'Remove local user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "user/$encodedId"
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
