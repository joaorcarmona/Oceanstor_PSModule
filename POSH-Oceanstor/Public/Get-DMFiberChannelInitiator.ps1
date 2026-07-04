<#
.SYNOPSIS
    Retrieves Fibre Channel initiators from the OceanStor device manager.

.DESCRIPTION
    Returns Fibre Channel initiators for all hosts, for a specific host, or for free initiators that are not yet attached to a host.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER HostName
    Name of the host whose Fibre Channel initiators should be returned.

.PARAMETER FreeInitiators
    Returns only free Fibre Channel initiators that are not assigned to a host.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorHostinitiatorFC

.EXAMPLE
    PS> Get-DMFiberChannelInitiator -HostName 'host01'

    Returns the Fibre Channel initiators associated with host01.

.EXAMPLE
    PS> Get-DMFiberChannelInitiator -FreeInitiators

    Returns Fibre Channel initiators that are not associated with a host.

.NOTES
    Filename: Get-DMFiberChannelInitiator.ps1
#>
function Get-DMFiberChannelInitiator {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(DefaultParameterSetName = 'All')]
    [OutputType([System.Object[]])]
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
                    $script:CurrentOceanstorSession
                }
                $matchingItems = @(Get-DMhost -WebSession $session -Name $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName '$candidate'. No host with that name exists."
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

        [Parameter(ParameterSetName = 'Free')]
        [switch]$FreeInitiators
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    if ($HostName) {
        $hostObject = @(Get-DMhost -WebSession $session -Name $HostName)[0]
        if ($null -eq $hostObject) { throw "Could not resolve 'hostObject' — the object may have been removed since parameter validation." }
        return @(Get-DMHostInitiator -WebSession $session -InitiatorType FibreChannel -HostId $hostObject.Id)
    }
    if ($FreeInitiators) {
        return @(Get-DMHostInitiator -WebSession $session -InitiatorType FibreChannel -FreeInitiators)
    }
    return @(Get-DMHostInitiator -WebSession $session -InitiatorType FibreChannel -All)
}
