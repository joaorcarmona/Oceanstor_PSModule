function Unlock-DMLocalUser {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,
        [Parameter(Mandatory = $true)][string]$Id,
        [hashtable]$Property = @{}
    )

    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $encodedId = [uri]::EscapeDataString($Id)
    if ($PSCmdlet.ShouldProcess($Id, 'Unlock local user')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource "unlockuser/$encodedId" -BodyData $Property
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
