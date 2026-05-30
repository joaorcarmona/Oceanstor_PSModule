function Remove-DMLunFromLunGroup {
    <#
    .SYNOPSIS
        Removes a LUN association from a Huawei OceanStor LUN group.
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

        [Parameter(Mandatory = $true, Position = 2)]
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

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $lun = @(Get-DMluns -WebSession $session | Where-Object Name -EQ $LunName)[0]
    $group = @(Get-DMlunGroups -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    $members = @(Get-DMlunsbyLunGroup -WebSession $session -LunGroup $group)
    if ($members.Id -notcontains $lun.Id) {
        throw "LUN '$LunName' is not a member of LUN group '$LunGroupName'."
    }

    $parameters = @("ID=$($group.Id)", 'ASSOCIATEOBJTYPE=11', "ASSOCIATEOBJID=$($lun.Id)")
    if ($VstoreId) {
        $parameters += "vstoreId=$VstoreId"
    }
    $resource = "lungroup/associate?$($parameters -join '&')"

    if ($PSCmdlet.ShouldProcess("$LunName <- $LunGroupName", 'Remove LUN from LUN group')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource).error
    }
}
