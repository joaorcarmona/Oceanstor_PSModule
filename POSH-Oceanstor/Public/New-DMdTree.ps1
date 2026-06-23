function New-DMdTree {
    <#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage Filesystem (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage FileSystem (requires the NAS license)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .PARAMETER FileSystemName
        Name of the FileSystem to be used as parent of the dTree. This parameter is mandatory if the FileSystemID is not defined

    .PARAMETER FileSystemID
        ID of the FileSystem to be used as parent of the dTree. This parameter is mandatory if the FileSystemName is not defined

    .PARAMETER dTreeName
        Name of the dTree to be created

    .PARAMETER quotaSwitch
        If the Quota is enabled on the dTree  (default disabled)

    .PARAMETER vStoreId
        ID of the vStore where the dTree will be created

    .PARAMETER path
        Path of the dTree

    .PARAMETER securityStyle
        Security Style of the dTree (Native, NTFS, UNIX, Mixed)  (default Native)

    .PARAMETER lockingPolicy
        Locking Policy of the dTree (Mandatory, Advisory)  (default Mandatory)

	.INPUTS
		System.Management.Automation.PSCustomObject
		System.String
		System.Boolean

		You can pipe an OceanStor session object to WebSession and provide DTree creation values by property name.

	.OUTPUTS
		OceanStorDtree
		System.Management.Automation.PSCustomObject

		Returns the created DTree object on success, or the OceanStor API error object on failure.

	.EXAMPLE

		PS C:\> New-DMdTree -webSession $session -dTreeName "dTree1" -FileSystemId 150

		OR

		PS C:\> New-DMdTree -dTreeName "dTree1" -FileSystemId 150

	.NOTES
		Filename: New-DMFileSystem.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'byId')]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 1, Mandatory = $true)]
        [string]$dTreeName,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 2, Mandatory = $true, ParameterSetName = "byName")]
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
        [string]$fileSystemName,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $true, ParameterSetName = "byId")]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $fileSystems = @(Get-DMFileSystem -WebSession $session)
                if ($fileSystems.Id -contains $_) {
                    return $true
                }
                throw "Invalid FileSystemId. Valid values are: $($fileSystems.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMFileSystem -WebSession $session).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$fileSystemId,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [ValidateSet("enabled", "disabled")]
        [string]$quotaSwitch,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [string]$vStoreId,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [string]$path,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [ValidateSet("Native", "NTFS", "UNIX", "Mixed")]
        [string]$securityStyle,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $false, Position = 0, Mandatory = $false)]
        [ValidateSet("Mandatory", "Advisory")]
        [string]$lockingPolicy
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    $body = @{
        NAME       = $dTreeName;
        PARENTTYPE = 40
    }

    if ($vStoreId) {
        $body.Add("vstoreId", $vStoreId)
    }

    if ($PSBoundParameters.ContainsKey('quotaSwitch')) {
        $body.Add("QUOTASWITCH", ($quotaSwitch -eq "enabled"))
    }

    if ($path) {
        $body.Add("path", $path)
    }

    if ($PSBoundParameters.ContainsKey('lockingPolicy')) {
        switch ($lockingPolicy) {
            "Mandatory" {
                $body.Add("nasLockingPolicy", 0)
            }
            "Advisory" {
                $body.Add("nasLockingPolicy", 1)
            }
        }
    }

    if ($fileSystemId) {
        $body.Add("PARENTID", $fileSystemId)
    }
    else {
        $body.Add("PARENTNAME", $fileSystemName)
    }

    if ($securityStyle) {
        switch ($securityStyle) {
            "Native" {
                $body.Add("securityStyle", 1)
            }
            "NTFS" {
                $body.Add("securityStyle", 2)
            }
            "UNIX" {
                $body.Add("securityStyle", 3)
            }
            "Mixed" {
                $body.Add("securityStyle", 4)
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($dTreeName, 'Create dTree')) {
        $response = Invoke-DeviceManager -WebSession $session -Method "POST" -Resource "QUOTATREE" -BodyData $body

        if ($response.error.Code -eq 0) {
            $result = [OceanStorDtree]::new($response.data, $session)
        }
        else {
            $result = $response.error
        }

        return $result
    }
}





