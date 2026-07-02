function New-DMnfsClient {
    <#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage NFS Export (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage NFS Export (requires the NAS License)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER clientName
        The name of the NFS Client

    .PARAMETER shareId
        The ID of the NFS Share to be used by the client

    .PARAMETER Permission
        The permission of the client on the share. Default is "read-only"

    .PARAMETER permissionContraint
        The permission constraint of the client on the share. Default is "no_all_squash"

    .PARAMETER rootPermissionConstraint
        The root permission constraint of the client on the share. Default is "root_squash"

    .PARAMETER sourcePortVerify
        The source port verification of the client on the share. Default is "disabled"

    .PARAMETER vStoreId
        The ID of the vStore to be used by the client

	.INPUTS
		System.Management.Automation.PSCustomObject
		System.String
		System.Boolean

		You can pipe an OceanStor session object to WebSession and provide NFS client permission values by property name.

	.OUTPUTS
		OceanstorNFSclient
		System.Management.Automation.PSCustomObject

		Returns the created NFS share authorization client object on success, or the OceanStor API error object on failure.

	.EXAMPLE

		PS C:\> New-DMnfsClient -webSession $session

		OR

		PS C:\> New-DMnfsClient

	.NOTES
		Filename: New-DMnfsClient.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [string]$clientName,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $shares = @(Get-DMShare -WebSession $session -ShareType NFS)
                if ($shares.Id -contains $_) {
                    return $true
                }
                throw "Invalid ShareId. Valid values are: $($shares.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMShare -WebSession $session -ShareType NFS).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$shareId,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [ValidateSet("read-only", "read-write", "no-permission")]
        [string]$Permission = "read-only",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [ValidateSet("all_squash", "no_all_squash")]
        [string]$permissionContraint = "no_all_squash",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [ValidateSet("root_squash", "no_root_squash")]
        [string]$rootPermissionConstraint = "root_squash",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [ValidateSet("enabled", "disabled")]
        [string]$sourcePortVerify = "disabled",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [Int16]$vStoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    switch ($Permission) {
        "read-only" {
            $accessval = 0
        }
        "read-write" {
            $accessval = 1
        }
        "no-permission" {
            $accessval = 5
        }
    }
    switch ($permissionContraint) {
        "all_squash" {
            $allsquash = 0
        }
        "no_all_squash" {
            $allsquash = 1
        }
    }

    switch ($rootPermissionConstraint) {
        "root_squash" {
            $rootSquash = 0
        }
        "no_root_squash" {
            $rootSquash = 1
        }
    }

    switch ($sourcePortVerify) {
        "enabled" {
            $secure = 0
        }
        "disabled" {
            $secure = 1
        }
    }

    $body = @{
        NAME       = $clientName;
        PARENTID   = $shareId;
        ACCESSVAL  = $accessval;
        ALLSQUASH  = $allsquash;
        ROOTSQUASH = $rootSquash;
        SECURE     = $secure;
    }

    if ($vStoreId) {
        $body.Add("vstoreId", $vStoreId)
    }

    if ($PSCmdlet.ShouldProcess($clientName, 'Create NFS client')) {
        $response = Invoke-DeviceManager -WebSession $session -Method "POST" -Resource "NFS_SHARE_AUTH_CLIENT" -BodyData $body
        $response = $response | Assert-DMApiSuccess

        if ($response.error.Code -eq 0) {
            $result = [OceanstorNFSclient]::new($response.data, $session)
        }
        else {
            $result = $response.error
        }

        return $result.Id
    }
}
