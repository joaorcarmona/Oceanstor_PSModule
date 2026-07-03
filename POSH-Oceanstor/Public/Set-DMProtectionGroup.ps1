<#
.SYNOPSIS
    Modifies an OceanStor protection group.

.DESCRIPTION
    Modifies a protection group by Name or Id. NewName and Description are first-class properties.
    Name and Id are mutually exclusive, enforced by PowerShell parameter sets.

    Accepts multiple protection groups from the pipeline by property name (e.g. Get-DMProtectionGroup
    output). Each protection group is modified independently: a failure (e.g. an invalid/ambiguous
    name, a name collision, or a REST error) is reported as a non-terminating error and does not stop
    the rest from being processed. NewName is not meaningful for a batch of more than one group.

.PARAMETER WebSession
    Optional session returned by Connect-deviceManager. The module's cached $script:CurrentOceanstorSession session is used by default.

.PARAMETER Name
    Existing protection group name to modify. Supports tab completion. Mutually exclusive with Id.

.PARAMETER Id
    Existing protection group Id to modify. Validated against existing protection groups, no tab completion. Mutually exclusive with Name.

.PARAMETER NewName
    New name for the protection group.

.PARAMETER Description
    New description. An empty string clears the description.

.PARAMETER VstoreId
    Optional vStore ID used to scope the operation.

.INPUTS
    System.Management.Automation.PSCustomObject

    You can pipe an OceanStor session object to WebSession, or a protection group object (from Get-DMProtectionGroup) by property name.

.OUTPUTS
    System.Management.Automation.PSCustomObject

    Returns the OceanStor API error object indicating success or failure of the modification.

.EXAMPLE
    PS> Set-DMProtectionGroup -Name 'pg-production' -NewName 'pg-production-2' -WhatIf

.EXAMPLE
    PS> Set-DMProtectionGroup -Id 5 -Description 'Updated description'

.EXAMPLE
    PS> Get-DMProtectionGroup 'pg-production' | Set-DMProtectionGroup -Description 'Tier 1'

.NOTES
    Filename: Set-DMProtectionGroup.ps1
#>
function Set-DMProtectionGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
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
        [string]$Id,

        [ValidateLength(1, 255)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 255)][string]$Description,
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

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $resolved = @(Get-DMProtectionGroup -WebSession $session -Id $Id)[0]
                if ($null -eq $resolved) { throw "Could not resolve 'Id' - the object may have been removed since parameter validation." }
                $currentName = $resolved.Name
            }
            else {
                $currentName = $Name
            }

            $update = New-DMNamedObjectUpdate -Objects @(Get-DMProtectionGroup -WebSession $session) `
                -CurrentName $currentName -EntityName 'protection group' -ResourceBase 'protectgroup' -NewName $NewName `
                -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
                -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -VstoreId $VstoreId `
                -NameField 'protectGroupName' -DescriptionField 'description'

            if ($PSCmdlet.ShouldProcess($currentName, $update.Action)) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body -ApiV2
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}