function Add-DMPortToPortGroup {
    <#
    .SYNOPSIS
        Associates a Huawei OceanStor port with a port group.
    #>
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
                $ports = @(Get-DMPortGroupCandidates -WebSession $session -PortType $PortType)
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
                (Get-DMPortGroupCandidates -WebSession $session -PortType $fakeBoundParameters.PortType).Name |
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
    $port = @(Get-DMPortGroupCandidates -WebSession $session -PortType $PortType | Where-Object Name -EQ $PortName)[0]
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
