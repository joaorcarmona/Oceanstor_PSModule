<#
.SYNOPSIS
    Removes an OceanStor LUN from a LUN group.

.DESCRIPTION
    Removes an existing LUN association from an existing LUN group by resolving both objects by name.
    The cmdlet validates that the LUN is currently a member of the group before calling the OceanStor API and supports -WhatIf and -Confirm.

    Accepts multiple LUNs from the pipeline by property name. Each LUN is resolved and processed
    independently: a failure (e.g. an invalid/ambiguous name, or the LUN not being a member) is
    reported as a non-terminating error and does not stop the remaining LUNs from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunName
    Name of the LUN to remove from the LUN group. The name is validated against existing OceanStor LUNs.

.PARAMETER LunGroupName
    Name of the LUN group from which the LUN will be removed. The name is validated against existing OceanStor LUN groups.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMLunFromLunGroup -LunName 'lun01' -LunGroupName 'production-luns' -WhatIf

    Shows what would happen if lun01 were removed from the production-luns LUN group.

.NOTES
    Filename: Remove-DMLunFromLunGroup.ps1
#>
function Remove-DMLunFromLunGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

        [string]$VstoreId
    )

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

            $members = @(Get-DMlun -WebSession $session -LunGroup $group)
            if ($members.Id -notcontains $lun.Id) {
                throw "LUN '$LunName' is not a member of LUN group '$LunGroupName'."
            }

            $parameters = @("ID=$($group.Id)", 'ASSOCIATEOBJTYPE=11', "ASSOCIATEOBJID=$($lun.Id)")
            if ($VstoreId) {
                $parameters += "vstoreId=$VstoreId"
            }
            $resource = "lungroup/associate?$($parameters -join '&')"

            if ($PSCmdlet.ShouldProcess("$LunName <- $LunGroupName", 'Remove LUN from LUN group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
