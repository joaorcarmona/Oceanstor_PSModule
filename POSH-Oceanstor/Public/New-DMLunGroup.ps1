<#
.SYNOPSIS
    Creates an OceanStor LUN group.

.DESCRIPTION
    Creates a LUN group in OceanStor with a name, application type, optional description, and optional vStore scope.
    The cmdlet returns the created LUN group object when the API call succeeds.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER Name
    Name of the LUN group to create. The value must be 1 to 255 characters and may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER ApplicationType
    Application type metadata for the LUN group. Valid values are Other, Oracle, Exchange, SQL Server, VMWare, and Hyper-V.

.PARAMETER Description
    Optional description for the LUN group. The value can be up to 255 characters.

.PARAMETER VstoreId
    Optional vStore ID used to scope the LUN group creation operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanStorLunGroup
    Returns the created LUN group object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMLunGroup -Name 'production-luns' -ApplicationType 'VMWare' -Description 'VMware datastore LUNs'

    Creates a LUN group named production-luns with VMware application metadata.

.NOTES
    Filename: New-DMLunGroup.ps1
#>
function New-DMLunGroup {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 255)]
        [ValidatePattern('^[A-Za-z0-9_.-]+$')]
        [string]$Name,

        [Parameter(Position = 2)]
        [ValidateSet('Other', 'Oracle', 'Exchange', 'SQL Server', 'VMWare', 'Hyper-V')]
        [string]$ApplicationType = 'Other',

        [Parameter(Position = 3)]
        [ValidateLength(0, 255)]
        [string]$Description,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $applicationTypeValue = @{
        'Other'      = 0
        'Oracle'     = 1
        'Exchange'   = 2
        'SQL Server' = 3
        'VMWare'     = 4
        'Hyper-V'    = 5
    }[$ApplicationType]
    $body = @{
        NAME      = $Name
        APPTYPE   = $applicationTypeValue
        GROUPTYPE = 0
    }
    if ($PSBoundParameters.ContainsKey('Description')) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Create LUN group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'lungroup' -BodyData $body
        if ($response.error.Code -eq 0) {
            return [OceanStorLunGroup]::new($response.data, $session)
        }

        return $response.error
    }
}
