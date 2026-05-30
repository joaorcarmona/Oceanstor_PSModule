function Remove-DMHostGroupFromMappingView {
    <#
    .SYNOPSIS
        Removes a host group association from a Huawei OceanStor mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $views = @(Get-DMMappingView -WebSession $session)
                $matchingItems = @($views | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "MappingViewName is ambiguous because more than one mapping view is named '$_'."
                }
                throw "Invalid MappingViewName. Valid values are: $($views.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMMappingView -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$MappingViewName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $groups = @(Get-DMhostGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostGroupName is ambiguous because more than one host group is named '$_'."
                }
                throw "Invalid HostGroupName. Valid values are: $($groups.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhostGroups -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostGroupName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if (-not $view) {
        throw "Mapping view '$MappingViewName' was not found."
    }
    $group = @(Get-DMhostGroups -WebSession $session | Where-Object Name -EQ $HostGroupName)[0]
    if (-not $group) {
        throw "Host group '$HostGroupName' was not found."
    }
    $associations = @(Get-DMMappingView -WebSession $session -HostGroupName $HostGroupName -VstoreId $VstoreId)
    if ($associations.Id -notcontains $view.Id) {
        throw "Host group '$HostGroupName' is not associated with mapping view '$MappingViewName'."
    }

    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 14; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$HostGroupName <- $MappingViewName", 'Remove host group from mapping view')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/REMOVE_ASSOCIATE' -BodyData $body).error
    }
}
