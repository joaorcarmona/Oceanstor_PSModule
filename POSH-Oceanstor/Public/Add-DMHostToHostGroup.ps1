<#
.SYNOPSIS
    Associates an OceanStor host with a host group.

.DESCRIPTION
    Adds an existing host to an existing host group by resolving both objects by name.
    The cmdlet validates the host and host group before calling the OceanStor API and supports -WhatIf and -Confirm.

    Accepts multiple hosts from the pipeline by property name. Each host is resolved and associated
    independently: a failure (e.g. an invalid/ambiguous name, or a REST error) is reported as a
    non-terminating error and does not stop the remaining hosts from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER HostName
    Name of the host to add to the host group. Resolved against existing OceanStor hosts when the command runs. Accepts pipeline input by property name (a piped object's Name property).

.PARAMETER HostGroupName
    Name of the host group that will receive the host. Resolved against existing OceanStor host groups when the command runs.

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

.EXAMPLE
    PS> Get-DMhost | Where-Object Name -Like 'esx*' | Add-DMHostToHostGroup -HostGroupName 'production-hosts' -Confirm:$false

    Adds every host whose name starts with esx to the production-hosts host group. A host that fails
    is reported as a non-terminating error; the rest are still processed.

.NOTES
    Filename: Add-DMHostToHostGroup.ps1
#>
function Add-DMHostToHostGroup {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(Mandatory = $true, Position = 2)]
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

            $body = @{
                ID               = $group.Id
                ASSOCIATEOBJTYPE = 21
                ASSOCIATEOBJID   = $hostObject.Id
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$HostName -> $HostGroupName", 'Associate host with host group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'hostgroup/associate' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
