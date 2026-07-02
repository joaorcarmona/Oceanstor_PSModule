<#
.SYNOPSIS
    Removes an OceanStor host group.

.DESCRIPTION
    Deletes an existing host group by name, optionally scoped to a vStore.
    The host group name is validated against existing OceanStor host groups before the delete request is sent. The cmdlet supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER HostGroupName
    Name of the host group to remove. The name is validated against existing OceanStor host groups.

.PARAMETER VstoreId
    Optional vStore ID used to scope the host group removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMHostGroup -HostGroupName 'production-hosts' -WhatIf

    Shows what would happen if the production-hosts host group were removed.

.NOTES
    Filename: Remove-DMHostGroup.ps1
#>
function Remove-DMHostGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

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
                    $script:CurrentOceanstorSession
                }
                $groups = @(Get-DMhostGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$_'."
                }
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMhostGroup -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $group = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $resource = "hostgroup/$($group.Id)"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    if ($PSCmdlet.ShouldProcess($HostGroupName, 'Remove host group')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        $response = $response | Assert-DMApiSuccess
        return $response.error
    }
}
