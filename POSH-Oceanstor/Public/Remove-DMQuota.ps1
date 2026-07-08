function Remove-DMQuota {
    <#
    .SYNOPSIS
        Removes an OceanStor quota.

    .DESCRIPTION
        Deletes a quota via DELETE FS_QUOTA/{id}. Accepts quotas from the pipeline
        (e.g. from Get-DMQuota) by property name. Each quota is removed independently:
        a failure is reported as a non-terminating error and does not stop the rest
        from being processed.

    .PARAMETER WebSession
        Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

    .PARAMETER Id
        Composite quota ID (e.g. '34@4@1') to remove.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        PS> Get-DMQuota -FileSystemName 'fs01' | Remove-DMQuota -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            if (-not $PSCmdlet.ShouldProcess($Id, 'Remove quota')) {
                return
            }

            # The composite quota ID (e.g. '2671@4097@3') must be sent literally in the
            # path. URL-encoding the '@' as %40 makes this firmware return 404 Not Found.
            $resource = "FS_QUOTA/$Id"
            $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
            $response = $response | Assert-DMApiSuccess
            return $response.error
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
