function Add-DMLunGroupToMappingView {
    <#
    .SYNOPSIS
        Associates a Huawei OceanStor LUN group with a mapping view.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
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
                $groups = @(Get-DMlunGroups -WebSession $session)
                $matchingItems = @($groups | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "LunGroupName is ambiguous because more than one LUN group is named '$_'."
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
    $view = @(Get-DMMappingView -WebSession $session | Where-Object Name -EQ $MappingViewName)[0]
    if (-not $view) {
        throw "Mapping view '$MappingViewName' was not found."
    }
    $group = @(Get-DMlunGroups -WebSession $session | Where-Object Name -EQ $LunGroupName)[0]
    if (-not $group) {
        throw "LUN group '$LunGroupName' was not found."
    }
    $body = @{ TYPE = 245; ID = $view.Id; ASSOCIATEOBJTYPE = 256; ASSOCIATEOBJID = $group.Id }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    if ($PSCmdlet.ShouldProcess("$LunGroupName -> $MappingViewName", 'Associate LUN group with mapping view')) {
        return (Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource 'mappingview/CREATE_ASSOCIATE' -BodyData $body).error
    }
}
