<#
.SYNOPSIS
    Removes an OceanStor LUN from a LUN group.

.DESCRIPTION
    Removes an existing LUN association from an existing LUN group by resolving both objects by name.
    The cmdlet validates that the LUN is currently a member of the group before calling the OceanStor API and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

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
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $luns = @(Get-DMlun -WebSession $session)
                $matchingItems = @($luns | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$candidate'."
                }
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMlun -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMlunGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$candidate'."
                }
                throw "Invalid LunGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMlunGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $lun = @(Get-DMlun -WebSession $session | Where-Object Name -EQ $LunName)[0]
    $group = @(Get-DMlunGroup -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    $members = @(Get-DMlunbyLunGroup -WebSession $session -LunGroup $group)
    if ($members.Id -notcontains $lun.Id) {
        throw "LUN '$LunName' is not a member of LUN group '$LunGroupName'."
    }

    $parameters = @("ID=$($group.Id)", 'ASSOCIATEOBJTYPE=11', "ASSOCIATEOBJID=$($lun.Id)")
    if ($VstoreId) {
        $parameters += "vstoreId=$VstoreId"
    }
    $resource = "lungroup/associate?$($parameters -join '&')"

    if ($PSCmdlet.ShouldProcess("$LunName <- $LunGroupName", 'Remove LUN from LUN group')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource).error
    }
}
