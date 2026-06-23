<#
.SYNOPSIS
    Associates an OceanStor port with a port group.

.DESCRIPTION
    Adds an existing front-end port or logical port to an existing port group.
    The cmdlet resolves candidate ports by PortType, validates the selected port and group, then calls the OceanStor API. It supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

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
                    $deviceManager
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
                    $deviceManager
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
                    $deviceManager
                }
                $ports = @(Get-DMPortGroupCandidate -WebSession $session -PortType $PortType)
                $matchingItems = @($ports | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "PortName is ambiguous because more than one $PortType port is named '$candidate'."
                }
                throw "Invalid PortName for $PortType. Valid values are: $($ports.Name -join ', ')"
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
                    $deviceManager
                }
                (Get-DMPortGroupCandidate -WebSession $session -PortType $fakeBoundParameters.PortType).Name |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$PortName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $group = @(Get-DMPortGroup -WebSession $session | Where-Object Name -EQ $PortGroupName)[0]
    $port = @(Get-DMPortGroupCandidate -WebSession $session -PortType $PortType | Where-Object Name -EQ $PortName)[0]
    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = $port.ObjectType
        ASSOCIATEOBJID   = $port.Id
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$PortName -> $PortGroupName", 'Associate port with port group')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'port/associate/portgroup' -BodyData $body).error
    }
}
