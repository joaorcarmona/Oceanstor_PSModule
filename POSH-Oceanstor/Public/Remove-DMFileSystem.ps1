function Remove-DMFileSystem {
    <#
    .SYNOPSIS
        Removes a Huawei OceanStor file system.
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

        [switch]$Force,

        [switch]$Worm,

        [string]$VstoreId
    )

    $session = if ($WebSession) { $WebSession } else { $deviceManager }
    $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    $parameters = @()
    if ($Force) { $parameters += 'forceDeleteFs=true' }
    if ($Worm) { $parameters += 'SUBTYPE=1' }
    if ($VstoreId) { $parameters += "vstoreId=$VstoreId" }
    $resource = "filesystem/$($fileSystem.Id)"
    if ($parameters.Count -gt 0) { $resource += "?$($parameters -join '&')" }

    if ($PSCmdlet.ShouldProcess($FileSystemName, 'Remove file system and its data')) {
        $response = invoke-DeviceManager -WebSession $session -Method 'DELETE' -Resource $resource
        return $response.error
    }
}
