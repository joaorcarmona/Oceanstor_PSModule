function Switch-DMVStorePair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession, [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id)
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess($Id, 'Switch vStore pair role')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'VSTORE_PAIR/swap' -BodyData @{ ID = $Id }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
