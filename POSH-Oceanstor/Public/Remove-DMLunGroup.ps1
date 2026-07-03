<#
.SYNOPSIS
    Removes an OceanStor LUN group.

.DESCRIPTION
    Deletes an existing LUN group by name, optionally scoped to a vStore.
    The LUN group name is validated against existing OceanStor LUN groups before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple LUN groups from the pipeline by property name. Each LUN group is resolved and
    removed independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as
    a non-terminating error and does not stop the remaining LUN groups from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER LunGroupName
    Name of the LUN group to remove. The name is validated against existing OceanStor LUN groups.

.PARAMETER VstoreId
    Optional vStore ID used to scope the LUN group removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMLunGroup -LunGroupName 'production-luns' -WhatIf

    Shows what would happen if the production-luns LUN group were removed.

.NOTES
    Filename: Remove-DMLunGroup.ps1
#>
function Remove-DMLunGroup {
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

            $groups = @(Get-DMlunGroup -WebSession $session)
            $matchingGroups = @($groups | Where-Object Name -EQ $LunGroupName)
            if ($matchingGroups.Count -eq 0) {
                throw "Invalid LunGroupName. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingGroups.Count -gt 1) {
                throw "LunGroupName is ambiguous because more than one LUN group is named '$LunGroupName'."
            }
            $group = $matchingGroups[0]

            $resource = "lungroup/$($group.Id)"
            if ($VstoreId) {
                $resource += "?vstoreId=$VstoreId"
            }

            if ($PSCmdlet.ShouldProcess($LunGroupName, 'Remove LUN group')) {
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
