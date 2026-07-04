<#
.SYNOPSIS
    Removes an OceanStor host from a host group.

.DESCRIPTION
    Removes an existing host association from an existing host group by resolving both objects by name.
    The cmdlet validates that the host is currently a member of the group before calling the OceanStor API and supports -WhatIf and -Confirm.

    Accepts multiple hosts from the pipeline by property name. Each host is resolved and processed
    independently: a failure (e.g. an invalid/ambiguous name, or the host not being a member) is
    reported as a non-terminating error and does not stop the remaining hosts from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0, ValueFromPipelineByPropertyName = $true)]
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
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
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

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $matchingHosts = @(Get-DMhost -WebSession $session -Name $HostName)
            if ($matchingHosts.Count -eq 0) {
                throw "Invalid HostName '$HostName'. No host with that name exists."
            }
            if ($matchingHosts.Count -gt 1) {
                throw "HostName is ambiguous because more than one host is named '$HostName'."
            }
            $hostObject = $matchingHosts[0]

            $groups = @(Get-DMhostGroup -WebSession $session)
            $matchingGroups = @($groups | Where-Object Name -EQ $HostGroupName)
            if ($matchingGroups.Count -eq 0) {
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingGroups.Count -gt 1) {
                throw "HostGroupName is ambiguous because more than one host group is named '$HostGroupName'."
            }
            $group = $matchingGroups[0]

            $members = @(Get-DMhost -WebSession $session -HostGroupId $group.Id)
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
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'host/associate' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
