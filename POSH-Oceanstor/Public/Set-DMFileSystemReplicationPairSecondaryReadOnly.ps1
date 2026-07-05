function Set-DMFileSystemReplicationPairSecondaryReadOnly {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession, [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id, [string]$VstoreId)
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{ ID = $Id }
    Add-DMOptionalBodyValue -Body $body -Key 'vstoreId' -Value $VstoreId -IsPresent $PSBoundParameters.ContainsKey('VstoreId')
    if ($PSCmdlet.ShouldProcess($Id, 'Set file-system replication secondary read-only')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'REPLICATIONPAIR/SET_SECONDARY_FILESYSTEM_READ_ONLY' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
