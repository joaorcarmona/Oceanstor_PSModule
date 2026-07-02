<#
.SYNOPSIS
    Creates an OceanStor host group.

.DESCRIPTION
    Creates a host group in OceanStor with a name, optional description, and optional vStore scope.
    The cmdlet returns the created host group object when the API call succeeds.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the host group to create. The value must be 1 to 255 characters and may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER Description
    Optional description for the host group. The value can be up to 255 characters.

.PARAMETER VstoreId
    Optional vStore ID used to scope the host group creation operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanStorHostGroup
    Returns the created host group object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMHostGroup -Name 'production-hosts' -Description 'Hosts for production workloads'

    Creates a host group named production-hosts.

.NOTES
    Filename: New-DMHostGroup.ps1
#>
function New-DMHostGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(Position = 2)]
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
        TYPE = 14
        NAME = $Name
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create host group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'hostgroup' -BodyData $body
        if ($response.error.Code -eq 0) {
            return [OceanStorHostGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
