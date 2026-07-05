function Disable-DMFileSystemReplicationPairSecondaryProtection {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param([Parameter(ValueFromPipelineByPropertyName = $true)][pscustomobject]$WebSession, [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$Id, [string]$VstoreId)
    $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
    $body = @{ ID = $Id }
    Add-DMOptionalBodyValue -Body $body -Key 'vstoreId' -Value $VstoreId -IsPresent $PSBoundParameters.ContainsKey('VstoreId')
    if ($PSCmdlet.ShouldProcess($Id, 'Disable file-system replication secondary protection')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'REPLICATIONPAIR/CANCEL_SECONDARY_WRITE_LOCK' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
