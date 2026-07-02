<#
.SYNOPSIS
    Associates an OceanStor host with a host group.

.DESCRIPTION
    Adds an existing host to an existing host group by resolving both objects by name.
    The cmdlet validates the host and host group before calling the OceanStor API and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER HostName
    Name of the host to add to the host group. The name is validated against existing OceanStor hosts.

.PARAMETER HostGroupName
    Name of the host group that will receive the host. The name is validated against existing OceanStor host groups.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMHostToHostGroup -HostName 'host01' -HostGroupName 'production-hosts' -WhatIf

    Shows what would happen if host01 were added to the production-hosts host group.

.NOTES
    Filename: Add-DMHostToHostGroup.ps1
#>
function Add-DMHostToHostGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
                $script:_dmAddHostHosts = @(Get-DMhost -WebSession $session)
                $matchingItems = @($script:_dmAddHostHosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName. Valid values are: $($script:_dmAddHostHosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
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
                    $script:CurrentOceanstorSession
                }
                $script:_dmAddHostGroups = @(Get-DMhostGroup -WebSession $session)
                $matchingItems = @($script:_dmAddHostGroups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$candidate'."
                }
                throw "Invalid HostGroupName. Valid values are: $($script:_dmAddHostGroups.Name -join ', ')"
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
    $hostObject = @($script:_dmAddHostHosts | Where-Object Name -EQ $HostName)[0]
    if ($null -eq $hostObject) { throw "Could not resolve 'hostObject' — the object may have been removed since parameter validation." }
    $group = @($script:_dmAddHostGroups | Where-Object Name -EQ $HostGroupName)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = 21
        ASSOCIATEOBJID   = $hostObject.Id
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$HostName -> $HostGroupName", 'Associate host with host group')) {
        return ((Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'hostgroup/associate' -BodyData $body) | Assert-DMApiSuccess).error
    }
}
