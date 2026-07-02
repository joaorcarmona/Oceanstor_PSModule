function New-DMMappingView {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor mapping view.

    .DESCRIPTION
        Creates a new mapping view with an optional description and vStore scope.

    .PARAMETER WebSession
        Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

    .PARAMETER Name
        Name of the mapping view to create.

    .PARAMETER Description
        Optional description for the mapping view.

    .PARAMETER VstoreId
        Optional vStore identifier to scope the creation request.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        Returns an OceanStorMappingView object on success or the API error object on failure.

    .EXAMPLE
        PS> New-DMMappingView -Name 'mv-prod' -Description 'Production mapping view'

    .NOTES
        Filename: New-DMMappingView.ps1
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [ValidateLength(0, 255)]
        [string]$Description,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $body = @{
        TYPE = 245
        NAME = $Name
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create mapping view')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'mappingview' -BodyData $body
        $response = $response | Assert-DMApiSuccess
        if ($response.error.Code -eq 0) {
            return [OceanStorMappingView]::new($response.data, $session)
        }

        return $response.error
    }
}
