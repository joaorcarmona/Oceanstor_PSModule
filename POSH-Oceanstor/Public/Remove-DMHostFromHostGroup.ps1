<#
.SYNOPSIS
    Removes an OceanStor host from a host group.

.DESCRIPTION
    Removes an existing host association from an existing host group by resolving both objects by name.
    The cmdlet validates that the host is currently a member of the group before calling the OceanStor API and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER HostName
    Name of the host to remove from the host group. The name is validated against existing OceanStor hosts.

.PARAMETER HostGroupName
    Name of the host group from which the host will be removed. The name is validated against existing OceanStor host groups.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMHostFromHostGroup -HostName 'host01' -HostGroupName 'production-hosts' -WhatIf

    Shows what would happen if host01 were removed from the production-hosts host group.

.NOTES
    Filename: Remove-DMHostFromHostGroup.ps1
#>
function Remove-DMHostFromHostGroup {
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
                $hosts = @(Get-DMhost -WebSession $session)
                $matchingItems = @($hosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMhostGroup -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$candidate'."
                }
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
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
        $deviceManager
    }
    $hostObject = @(Get-DMhost -WebSession $session | Where-Object Name -EQ $HostName)[0]
    $group = @(Get-DMhostGroup -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    $members = @(Get-DMhostbyHostGroupId -WebSession $session -HostGroupId $group.Id)
    if ($members.Id -notcontains $hostObject.Id) {
        throw "Host '$HostName' is not a member of host group '$HostGroupName'."
    }

    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = 21
        ASSOCIATEOBJID   = $hostObject.Id
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$HostName <- $HostGroupName", 'Remove host from host group')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'host/associate' -BodyData $body).error
    }
}
