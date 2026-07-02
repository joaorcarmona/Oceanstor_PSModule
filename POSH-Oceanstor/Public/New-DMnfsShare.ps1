function New-DMnfsShare {
    <#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage NFS Share (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage NFS Share (requires the NAS License)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER sharepath
        The path of the NFS Share to be created

    .PARAMETER FileSystemId
        The ID of the FileSystem to be used by the share

    .PARAMETER encoding
        The encoding of the share. Default is "UTF-8"

    .PARAMETER privateShare
        The type of the share. Default is "normal share"

    .PARAMETER dTree
        Optional DTree ID. When specified, the NFS share is scoped to the given DTree within the file system.

	.INPUTS
		System.Management.Automation.PSCustomObject
		System.String
		System.Boolean

		You can pipe an OceanStor session object to WebSession and provide NFS share creation values by property name.

	.OUTPUTS
		OceanStorNFSShare
		System.Management.Automation.PSCustomObject

		Returns the created NFS share object on success, or the OceanStor API error object on failure.

	.EXAMPLE

		PS C:\> New-DMnfsShare -webSession $session

		OR

		PS C:\> New-DMnfsShare

	.NOTES
		Filename: New-DMnfsShare.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [string]$sharepath,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
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
                    $script:CurrentOceanstorSession
                }
                (Get-DMFileSystem -WebSession $session).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemId,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [ValidateSet("UTF-8")]
        [string]$encoding = "UTF-8",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [string]$dTree,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [ValidateSet("normal share", "Private share")]
        [string]$privateShare = "normal share"
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    switch ($encoding) {
        "UTF-8" {
            $characterEncoding = 0
        }
    }

    switch ($privateShare) {
        "normal share" {
            $sharePrivate = 0
        }
        "private share" {
            $sharePrivate = 1
        }
    }

    $body = @{
        SHAREPATH         = $sharepath;
        FSID              = $FileSystemId;
        CHARACTERENCODING = $characterEncoding;
        sharePrivate      = $sharePrivate;
    }

    if ($dTree) {
        $body.Add("DTREEID", $dTree)
    }

    if ($PSCmdlet.ShouldProcess($sharepath, 'Create NFS share')) {
        $response = Invoke-DeviceManager -WebSession $session -Method "POST" -Resource "NFSSHARE" -BodyData $body
        $response = $response | Assert-DMApiSuccess

        if ($response.error.Code -eq 0) {
            $result = [OceanStorNFSShare]::new($response.data, $session)
        }
        else {
            $result = $response.error
        }

        return $result
    }
}
