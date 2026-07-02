<#
.SYNOPSIS
    Creates an OceanStor port group.

.DESCRIPTION
    Creates a port group in OceanStor with a name and optional description.
    The cmdlet returns the created port group object when the API call succeeds.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the port group to create. The value must be 1 to 255 characters and may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER Description
    Optional description for the port group. The value can be up to 63 characters.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorPortGroup
    Returns the created port group object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMPortGroup -Name 'fc-front-end' -Description 'Front-end Fibre Channel ports'

    Creates a port group named fc-front-end.

.NOTES
    Filename: New-DMPortGroup.ps1
#>
function New-DMPortGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(Position = 2)]
        [ValidateLength(0, 63)]
        [string]$Description
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $body = @{ NAME = $Name }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create port group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'portgroup' -BodyData $body
        if ($response.error.Code -eq 0) {
            return [OceanstorPortGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
