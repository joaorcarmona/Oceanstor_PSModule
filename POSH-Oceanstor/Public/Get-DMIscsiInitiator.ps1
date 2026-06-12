<#
.SYNOPSIS
    Retrieves iSCSI initiators from the OceanStor device manager.

.DESCRIPTION
    Returns iSCSI initiators for all hosts, for a specific host, or for free initiators that are not yet attached to a host.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER HostName
    Name of the host whose iSCSI initiators should be returned.

.PARAMETER FreeInitiators
    Returns only free iSCSI initiators that are not assigned to a host.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorHostinitiatorISCSI

.EXAMPLE
    PS> Get-DMIscsiInitiator -HostName 'host01'

    Returns the iSCSI initiators associated with host01.

.EXAMPLE
    PS> Get-DMIscsiInitiator -FreeInitiators

    Returns iSCSI initiators that are not associated with a host.

.NOTES
    Filename: Get-DMIscsiInitiator.ps1
#>
function Get-DMIscsiInitiator {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'Host')]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $hosts = @(Get-DMhosts -WebSession $session)
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
                (Get-DMhosts -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [Parameter(ParameterSetName = 'Free')]
        [switch]$FreeInitiators
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    if ($HostName) {
        $hostObject = @(Get-DMhosts -WebSession $session | Where-Object Name -EQ $HostName)[0]
        return @(Get-DMHostInitiators -WebSession $session -InitatorType ISCSI -HostId $hostObject.Id)
    }
    if ($FreeInitiators) {
        return @(Get-DMHostInitiators -WebSession $session -InitatorType ISCSI -FreeInitiators)
    }
    return @(Get-DMHostInitiators -WebSession $session -InitatorType ISCSI -All)
}
