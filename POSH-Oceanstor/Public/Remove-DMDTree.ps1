<#
.SYNOPSIS
    Removes an OceanStor dTree.

.DESCRIPTION
    Deletes an existing dTree from a file system by resolving the file system and dTree names before calling the OceanStor API.
    The cmdlet validates both names and supports -WhatIf and -Confirm.

    Accepts multiple dTrees from the pipeline by property name (all piped dTrees must belong to the
    same FileSystemName). Each dTree is resolved and removed independently: a failure (e.g. an
    invalid/ambiguous name, or a REST error) is reported as a non-terminating error and does not stop
    the remaining dTrees from being processed.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the module's cached $script:CurrentOceanstorSession session is used.

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
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemName,

        [Parameter(Mandatory = $true, Position = 2, ValueFromPipelineByPropertyName = $true)]
        [Alias('Name')]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('FileSystemName')) {
                    return
                }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
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

    process {
        try {
            $session = if ($WebSession) {
                $WebSession
            }
            else {
                $script:CurrentOceanstorSession
            }

            $fileSystems = @(Get-DMFileSystem -WebSession $session)
            $matchingFileSystems = @($fileSystems | Where-Object Name -EQ $FileSystemName)
            if ($matchingFileSystems.Count -eq 0) {
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            }
            if ($matchingFileSystems.Count -gt 1) {
                throw "FileSystemName is ambiguous because more than one file system is named '$FileSystemName'."
            }
            $fileSystem = $matchingFileSystems[0]

            $dtrees = @((Invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
            $matchingDtrees = @($dtrees | Where-Object NAME -EQ $DTreeName)
            if ($matchingDtrees.Count -eq 0) {
                throw "Invalid DTreeName. Valid values are: $($dtrees.NAME -join ', ')"
            }
            if ($matchingDtrees.Count -gt 1) {
                throw "DTreeName is ambiguous because more than one dTree is named '$DTreeName'."
            }
            $dtree = $matchingDtrees[0]

            $resource = "QUOTATREE/$($dtree.ID)"
            if ($VstoreId) {
                $resource += "?vstoreId=$VstoreId"
            }

            if ($PSCmdlet.ShouldProcess("$FileSystemName/$DTreeName", 'Remove dTree and its data')) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
