<#
.SYNOPSIS
    Removes an OceanStor protection group.

.DESCRIPTION
    Deletes an existing protection group by name through the API v2 protection group interface.
    The protection group name is validated before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER Name
    Name of the protection group to remove. The name is validated against existing OceanStor protection groups.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMProtectionGroup -Name 'pg-production' -WhatIf

    Shows what would happen if the pg-production protection group were removed.

.NOTES
    Filename: Remove-DMProtectionGroup.ps1
#>
function Remove-DMProtectionGroup {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMProtectionGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "Name is ambiguous because more than one protection group is named '$_'."
                }
                throw "Invalid protection group Name. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $group = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $Name)[0]

    if ($PSCmdlet.ShouldProcess($Name, 'Remove protection group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "protectgroup/$($group.Id)" -ApiV2
        return $response.error
    }
}
