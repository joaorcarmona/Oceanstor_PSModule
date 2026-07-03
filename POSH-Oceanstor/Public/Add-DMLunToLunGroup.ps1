<#
.SYNOPSIS
    Associates an OceanStor LUN with a LUN group.

.DESCRIPTION
    Adds an existing LUN to an existing LUN group. Optional host LUN ID settings can be supplied for the
    association. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUNs from the pipeline by property name (e.g. Get-DMlun output, matching its Name
    property). Each LUN is resolved and associated independently: a failure associating one LUN (e.g. an
    invalid/ambiguous LunName, or a REST error) is reported as a non-terminating error and does not stop
    the remaining LUNs from being processed. LunGroupName is resolved per item against that item's own
    session, so LUNs piped from different arrays are each associated with the matching LUN group on their
    own array.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used. When a LUN object piped from Get-DMlun carries its own session, that session is used instead.

.PARAMETER LunName
    Name of the LUN to add to the LUN group. Resolved against existing OceanStor LUNs (on the applicable session) when the command runs. Accepts pipeline input by property name (a piped object's Name property).

.PARAMETER LunGroupName
    Name of the LUN group that will receive the LUN. Resolved against existing OceanStor LUN groups (on the applicable session) when the command runs.

.PARAMETER HostLunId
    Specific host LUN ID to assign to the LUN association. Cannot be used with StartHostLunId.

.PARAMETER StartHostLunId
    Starting host LUN ID to use when assigning host LUN IDs. Cannot be used with HostLunId.

.PARAMETER Force
    Adds the force flag to the OceanStor association request.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMLunToLunGroup -LunName 'lun01' -LunGroupName 'production-luns' -WhatIf

    Shows what would happen if lun01 were added to the production-luns LUN group.

.EXAMPLE
    PS> Get-DMlun | Where-Object Name -EQ 'lun02' | Add-DMLunToLunGroup -LunGroupName 'production-luns' -HostLunId 12

    Adds lun02 to the production-luns LUN group and requests host LUN ID 12.

.EXAMPLE
    PS> Get-DMlun | Where-Object Name -Like 'temp-*' | Add-DMLunToLunGroup -LunGroupName 'production-luns' -Confirm:$false

    Adds every LUN whose name starts with temp- to the production-luns LUN group. A LUN that fails is
    reported as a non-terminating error; the rest are still processed.

.NOTES
    Filename: Add-DMLunToLunGroup.ps1
#>
function Add-DMLunToLunGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMlunGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [ValidateRange(0, 4095)]
        [int]$HostLunId,

        [ValidateRange(0, 4095)]
        [int]$StartHostLunId,

        [switch]$Force,

        [string]$VstoreId
    )

    begin {
        if ($PSBoundParameters.ContainsKey('HostLunId') -and $PSBoundParameters.ContainsKey('StartHostLunId')) {
            throw 'HostLunId and StartHostLunId cannot be specified together.'
        }
    }

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $luns = @(Get-DMlun -WebSession $session)
            $matchingLuns = @($luns | Where-Object Name -EQ $LunName)
            if ($matchingLuns.Count -eq 0) {
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            }
            if ($matchingLuns.Count -gt 1) {
                throw "LunName is ambiguous because more than one LUN is named '$LunName'."
            }
            $lun = $matchingLuns[0]

            $groups = @(Get-DMlunGroup -WebSession $session)
            $matchingGroups = @($groups | Where-Object Name -EQ $LunGroupName)
            if ($matchingGroups.Count -eq 0) {
                throw "Invalid LunGroupName. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingGroups.Count -gt 1) {
                throw "LunGroupName is ambiguous because more than one LUN group is named '$LunGroupName'."
            }
            $group = $matchingGroups[0]

            $body = @{
                ID               = $group.Id
                ASSOCIATEOBJTYPE = 11
                ASSOCIATEOBJID   = $lun.Id
            }
            if ($PSBoundParameters.ContainsKey('HostLunId')) {
                $body.hostLunID = $HostLunId
            }
            if ($PSBoundParameters.ContainsKey('StartHostLunId')) {
                $body.startHostLunId = $StartHostLunId
            }
            if ($Force) {
                $body.force = $true
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$LunName -> $LunGroupName", 'Associate LUN with LUN group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'lungroup/associate' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
