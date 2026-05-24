function Remove-DMDTree {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor dTree.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $fileSystems = @(get-DMFileSystem -WebSession $session)
                $matchingItems = @($fileSystems | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "FileSystemName is ambiguous because more than one file system is named '$_'." }
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                (get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $deviceManager }
                $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
                $dtrees = @((invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
                $matchingItems = @($dtrees | Where-Object NAME -EQ $_)
                if ($matchingItems.Count -eq 1) { return $true }
                if ($matchingItems.Count -gt 1) { throw "DTreeName is ambiguous because more than one dTree is named '$_'." }
                throw "Invalid DTreeName. Valid values are: $($dtrees.NAME -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if (-not $fakeBoundParameters.ContainsKey('FileSystemName')) { return }
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) { $fakeBoundParameters.WebSession } else { $deviceManager }
                $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $fakeBoundParameters.FileSystemName)[0]
                if (-not $fileSystem) { return }
                @((invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data).NAME |
                    Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$DTreeName,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    $dtrees = @((invoke-DeviceManager -WebSession $session -Method 'GET' -Resource "QUOTATREE?PARENTID=$($fileSystem.Id)").data)
    $dtree = @($dtrees | Where-Object NAME -EQ $DTreeName)[0]
    $resource = "QUOTATREE/$($dtree.ID)"
    if ($VstoreId) { $resource += "?vstoreId=$VstoreId" }

    if ($PSCmdlet.ShouldProcess("$FileSystemName/$DTreeName", 'Remove dTree and its data')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
