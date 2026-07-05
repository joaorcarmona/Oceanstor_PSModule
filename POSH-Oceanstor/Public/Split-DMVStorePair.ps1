function Split-DMVStorePair {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession, [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id)
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    if ($PSCmdlet.ShouldProcess($Id, 'Split vStore pair')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'VSTORE_PAIR/split' -BodyData @{ ID = $Id }
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
