<#
.SYNOPSIS
    Removes an OceanStor port group.

.DESCRIPTION
    Deletes an existing port group by name, optionally scoped to a vStore.
    The port group name is validated against existing OceanStor port groups before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER PortGroupName
    Name of the port group to remove. The name is validated against existing OceanStor port groups.

.PARAMETER VstoreId
    Optional vStore ID used to scope the port group removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMPortGroup -PortGroupName 'fc-front-end' -WhatIf

    Shows what would happen if the fc-front-end port group were removed.

.NOTES
    Filename: Remove-DMPortGroup.ps1
#>
function Remove-DMPortGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

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
                    $script:CurrentOceanstorSession
                }
                $groups = @(Get-DMPortGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "PortGroupName is ambiguous because more than one port group is named '$candidate'."
                }
                throw "Invalid PortGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMPortGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$PortGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $resource = "portgroup/$($group.Id)"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    if ($PSCmdlet.ShouldProcess($PortGroupName, 'Remove port group')) {
        return ((Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource) | Assert-DMApiSuccess).error
    }
}
