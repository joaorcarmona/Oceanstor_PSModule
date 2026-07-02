<#
.SYNOPSIS
    Associates an OceanStor port with a port group.

.DESCRIPTION
    Adds an existing front-end port or logical port to an existing port group.
    The cmdlet resolves candidate ports by PortType, validates the selected port and group, then calls the OceanStor API. It supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

.PARAMETER PortGroupName
    Name of the port group that will receive the port.

.PARAMETER PortType
    Type of port to add to the port group. Valid values are FibreChannel, Ethernet, and LogicalPort.

.PARAMETER PortName
    Name of the port to add to the port group. Valid values are resolved from the selected PortType.

.PARAMETER VstoreId
    Optional vStore ID used to scope the association operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Add-DMPortToPortGroup -PortGroupName 'fc-front-end' -PortType FibreChannel -PortName 'CTE0.A.IOM0.P0' -WhatIf

    Shows what would happen if the Fibre Channel port were added to the fc-front-end port group.

.NOTES
    Filename: Add-DMPortToPortGroup.ps1
#>
function Add-DMPortToPortGroup {
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
                $script:_dmAddPortGroups = @(Get-DMPortGroup -WebSession $session)
                $matchingItems = @($script:_dmAddPortGroups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "PortGroupName is ambiguous because more than one port group is named '$candidate'."
                }
                throw "Invalid PortGroupName. Valid values are: $($script:_dmAddPortGroups.Name -join ', ')"
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

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('FibreChannel', 'Ethernet', 'LogicalPort')]
        [string]$PortType,

        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $script:_dmAddPorts = @(Get-DMPortGroupCandidate -WebSession $session -PortType $PortType)
                $matchingItems = @($script:_dmAddPorts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "PortName is ambiguous because more than one $PortType port is named '$candidate'."
                }
                throw "Invalid PortName for $PortType. Valid values are: $($script:_dmAddPorts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('PortType')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                # Get-DMPortGroupCandidate is private and would not resolve here -- confirmed
                # empirically that an ArgumentCompleter scriptblock invoked by the real completion
                # engine can only reliably call already-public commands -- so its per-PortType
                # lookup is inlined directly instead of exposing it as a public command.
                $names = switch ($fakeBoundParameters.PortType) {
                    'FibreChannel' { (Get-DMPortFc -WebSession $session).Name }
                    'Ethernet' { (Get-DMPortETH -WebSession $session).Name }
                    'LogicalPort' { (Get-DMLif -WebSession $session).'LIF Name' }
                }
                $names | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$PortName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $script:CurrentOceanstorSession
    }
    $group = @($script:_dmAddPortGroups | Where-Object Name -EQ $PortGroupName)[0]
    if ($null -eq $group) { throw "Could not resolve 'group' — the object may have been removed since parameter validation." }
    $port = @($script:_dmAddPorts | Where-Object Name -EQ $PortName)[0]
    if ($null -eq $port) { throw "Could not resolve 'port' — the object may have been removed since parameter validation." }
    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = $port.ObjectType
        ASSOCIATEOBJID   = $port.Id
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$PortName -> $PortGroupName", 'Associate port with port group')) {
        return ((Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'port/associate/portgroup' -BodyData $body) | Assert-DMApiSuccess).error
    }
}
