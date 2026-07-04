<#
.SYNOPSIS
    Removes an OceanStor protection group.

.DESCRIPTION
    Deletes an existing protection group through the API v2 protection group interface.
    The protection group can be identified by Name or by Id; Name and Id are mutually exclusive,
    enforced by PowerShell parameter sets. Name is validated at parameter-binding time with tab
    completion; Id is validated too, but has no tab completion. The cmdlet supports -WhatIf and -Confirm.

    Accepts multiple protection groups from the pipeline by property name (e.g. Get-DMProtectionGroup
    output). Each protection group is resolved and removed independently: a failure (e.g. an
    invalid/ambiguous name, or a REST error) is reported as a non-terminating error and does not stop
    the remaining protection groups from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER Name
    Name of the protection group to remove. Validated against existing OceanStor protection groups and supports tab completion. Mutually exclusive with Id.

.PARAMETER Id
    Id of the protection group to remove. Validated against existing OceanStor protection groups, no tab completion. Mutually exclusive with Name.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMProtectionGroup -Name 'pg-production' -WhatIf

    Shows what would happen if the pg-production protection group were removed.

.EXAMPLE
    PS> Remove-DMProtectionGroup -Id 5 -Confirm:$false

.EXAMPLE
    PS> Get-DMProtectionGroup 'pg-production' | Remove-DMProtectionGroup -Confirm:$false

.NOTES
    Filename: Remove-DMProtectionGroup.ps1
#>
function Remove-DMProtectionGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "Name is ambiguous because more than one protection group is named '$_'." }
                throw 'Invalid Name.'
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMProtectionGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMProtectionGroup -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid Id.'
            })]
        [string]$Id
    )

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $group = @(Get-DMProtectionGroup -WebSession $session -Id $Id)[0]
                if ($null -eq $group) { throw "Could not resolve 'Id' - the object may have been removed since parameter validation." }
            }
            else {
                $group = @(Get-DMProtectionGroup -WebSession $session | Where-Object Name -EQ $Name)[0]
                if ($null -eq $group) { throw "Could not resolve 'Name' - the object may have been removed since parameter validation." }
            }

            if ($PSCmdlet.ShouldProcess($group.Name, 'Remove protection group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource "protectgroup/$($group.Id)" -ApiV2
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
