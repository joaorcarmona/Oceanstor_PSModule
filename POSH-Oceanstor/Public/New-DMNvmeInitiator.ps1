function New-DMNvmeInitiator {
    <#
    .SYNOPSIS
        Creates an NVMe over RoCE initiator in the OceanStor system.

    .DESCRIPTION
        Adds an NVMe over RoCE initiator NQN to the storage system with an optional friendly name and vStore scope.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Nqn
        NQN of the NVMe over RoCE initiator to create.

    .PARAMETER Name
        Optional friendly name for the initiator. The value must be 1 to 31 characters and may contain letters, numbers, underscores, periods, or hyphens.

    .PARAMETER VstoreId
        Optional vStore ID used to scope the initiator operation.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        OceanstorHostinitiatorNVMe
        Returns the created NVMe over RoCE initiator object on success, or the API error object on failure.

    .EXAMPLE
        PS> New-DMNvmeInitiator -Nqn 'nqn.2026-06.test:host01' -Name 'nvme-01'

        Creates an NVMe over RoCE initiator with a friendly name.

    .NOTES
        Filename: New-DMNvmeInitiator.ps1
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9][\x21-\x7e]{0,222}$')]
        [string]$Nqn,

        [ValidatePattern('^[A-Za-z0-9_.-]{1,31}$')]
        [string]$Name,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $body = @{ ID = $Nqn }
    if ($Name) {
        $body.NAME = $Name
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess($Nqn, 'Create NVMe initiator')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'NVMe_over_RoCE_initiator' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanstorHostinitiatorNVMe]::new($response.data, $session)
        }
        return $response.error
    }
}
