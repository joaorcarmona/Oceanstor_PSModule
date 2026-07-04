<#
.SYNOPSIS
    Associates an OceanStor port with a port group.

.DESCRIPTION
    Adds an existing front-end port or logical port to an existing port group.
    The cmdlet resolves candidate ports by PortType, validates the selected port and group, then calls the OceanStor API. It supports -WhatIf and -Confirm.

    Accepts multiple ports from the pipeline by property name (all piped ports must share the same
    PortType). Each port is resolved and associated independently: a failure (e.g. an invalid/ambiguous
    name, or a REST error) is reported as a non-terminating error and does not stop the remaining ports
    from being processed.

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
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
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

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateSet('FibreChannel', 'Ethernet', 'LogicalPort')]
        [string]$PortType,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
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

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $groups = @(Get-DMPortGroup -WebSession $session)
            $matchingGroups = @($groups | Where-Object Name -EQ $PortGroupName)
            if ($matchingGroups.Count -eq 0) {
                throw "Invalid PortGroupName. Valid values are: $($groups.Name -join ', ')"
            }
            if ($matchingGroups.Count -gt 1) {
                throw "PortGroupName is ambiguous because more than one port group is named '$PortGroupName'."
            }
            $group = $matchingGroups[0]

            $ports = @(Get-DMPortGroupCandidate -WebSession $session -PortType $PortType)
            $matchingPorts = @($ports | Where-Object Name -EQ $PortName)
            if ($matchingPorts.Count -eq 0) {
                throw "Invalid PortName for $PortType. Valid values are: $($ports.Name -join ', ')"
            }
            if ($matchingPorts.Count -gt 1) {
                throw "PortName is ambiguous because more than one $PortType port is named '$PortName'."
            }
            $port = $matchingPorts[0]

            $body = @{
                ID               = $group.Id
                ASSOCIATEOBJTYPE = $port.ObjectType
                ASSOCIATEOBJID   = $port.Id
            }
            if ($VstoreId) {
                $body.vstoreId = $VstoreId
            }

            if ($PSCmdlet.ShouldProcess("$PortName -> $PortGroupName", 'Associate port with port group')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'port/associate/portgroup' -BodyData $body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
