function Remove-DMPortFromPortGroup {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor port from a port group.
    #>
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
                $ports = @(get-DMPortGroupCandidates -WebSession $session -PortType $PortType)
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
                (get-DMPortGroupCandidates -WebSession $session -PortType $fakeBoundParameters.PortType).Name |
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
    $port = @(get-DMPortGroupCandidates -WebSession $session -PortType $PortType | Where-Object Name -EQ $PortName)[0]
    $associationResource = "portgroup/associate?ASSOCIATEOBJTYPE=$($port.ObjectType)&ASSOCIATEOBJID=$($port.Id)"
    if ($VstoreId) {
        $associationResource += "&vstoreId=$VstoreId"
    }

    $associations = @(invoke-DeviceManager -WebSession $session -Method 'GET' -Resource $associationResource |
            Select-Object -ExpandProperty data)
    if (-not @($associations | Where-Object ID -EQ $group.Id)) {
        throw "Port '$PortName' is not a member of port group '$PortGroupName'."
    }

    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = $port.ObjectType
        ASSOCIATEOBJID   = $port.Id
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$PortName <- $PortGroupName", 'Remove port from port group')) {
        return (invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource 'port/associate/portgroup' -BodyData $body).error
    }
}
