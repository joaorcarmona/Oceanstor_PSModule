<#
.SYNOPSIS
    Removes an OceanStor dTree.

.DESCRIPTION
    Deletes an existing dTree from a file system by resolving the file system and dTree names before calling the OceanStor API.
    The cmdlet validates both names and supports -WhatIf and -Confirm.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER FileSystemName
    Name of the file system that contains the dTree. The name is validated against existing OceanStor file systems.

.PARAMETER DTreeName
    Name of the dTree to remove. Valid values are resolved from the selected file system.

.PARAMETER VstoreId
    Optional vStore ID used to scope the dTree removal operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    System.Management.Automation.PSCustomObject
    Returns the OceanStor API error object.

.EXAMPLE
    PS> Remove-DMDTree -FileSystemName 'fs01' -DTreeName 'project-a' -WhatIf

    Shows what would happen if the project-a dTree were removed from fs01.

.NOTES
    Filename: Remove-DMDTree.ps1
#>
function Remove-DMDTree {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

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
                $fileSystems = @(Get-DMFileSystem -WebSession $session)
                $matchingItems = @($fileSystems | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "FileSystemName is ambiguous because more than one file system is named '$_'."
                }
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
                $dtrees = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
                $matchingItems = @($dtrees | Where-Object NAME -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "DTreeName is ambiguous because more than one dTree is named '$_'."
                }
                throw "Invalid DTreeName. Valid values are: $($dtrees.NAME -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('FileSystemName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fakeBoundParameters.FileSystemName)[0]
                if ($null -eq $fileSystem) { throw "Could not resolve 'fileSystem' — the object may have been removed since parameter validation." }
                if (-not $fileSystem) {
                    return
                }
                @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data).NAME |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$DTreeName,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $fileSystem = @(Get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    if ($null -eq $fileSystem) { throw "Could not resolve 'fileSystem' — the object may have been removed since parameter validation." }
    $dtrees = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
    $dtree = @($dtrees | Where-Object NAME -EQ $DTreeName)[0]
    if ($null -eq $dtree) { throw "Could not resolve 'dtree' — the object may have been removed since parameter validation." }
    $resource = "QUOTATREE/$($dtree.ID)"
    if ($VstoreId) {
        $resource += "?vstoreId=$VstoreId"
    }

    if ($PSCmdlet.ShouldProcess("$FileSystemName/$DTreeName", 'Remove dTree and its data')) {
        $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
