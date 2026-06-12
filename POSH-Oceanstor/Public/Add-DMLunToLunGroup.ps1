function Add-DMLunToLunGroup {
    <#
    .SYNOPSIS
        Associates a Huawei OceanStor LUN with a LUN group.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(ValueFromPipeline = $true, Position = 1)]
        [pscustomobject]$Lun,

        [Parameter(Position = 2)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $luns = @(Get-DMluns -WebSession $session)
                $matchingItems = @($luns | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunName is ambiguous because more than one LUN is named '$candidate'."
                }
                throw "Invalid LunName. Valid values are: $($luns.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMluns -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunName,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 3)]
        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMlunGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$candidate'."
                }
                throw "Invalid LunGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMlunGroups -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$LunGroupName,

        [ValidateRange(0, 4095)]
        [int]$HostLunId,

        [ValidateRange(0, 4095)]
        [int]$StartHostLunId,

        [switch]$Force,

        [string]$VstoreId
    )

    if ($PSBoundParameters.ContainsKey('HostLunId') -and $PSBoundParameters.ContainsKey('StartHostLunId')) {
        throw 'HostLunId and StartHostLunId cannot be specified together.'
    }

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }

    $resolvedLunName = if ($Lun -and $Lun.PSObject.Properties.Name -contains 'Name') {
        $Lun.Name
    }
    elseif ($LunName) {
        $LunName
    }
    else {
        throw 'LunName is required. Pass a LUN name or pipe a LUN object with a Name property.'
    }

    $lun = @(Get-DMluns -WebSession $session | Where-Object Name -EQ $resolvedLunName)[0]
    $group = @(Get-DMlunGroups -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    $body = @{
        ID               = $group.Id
        ASSOCIATEOBJTYPE = 11
        ASSOCIATEOBJID   = $lun.Id
    }
    if ($PSBoundParameters.ContainsKey('HostLunId')) {
        $body.hostLunID = $HostLunId
    }
    if ($PSBoundParameters.ContainsKey('StartHostLunId')) {
        $body.startHostLunId = $StartHostLunId
    }
    if ($Force) {
        $body.force = $true
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$resolvedLunName -> $LunGroupName", 'Associate LUN with LUN group')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'lungroup/associate' -BodyData $body).error
    }
}
