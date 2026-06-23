function New-DMnfsClient {
    <#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage NFS Export (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage NFS Export (requires the NAS License)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .PARAMETER clientName
        The name of the NFS Client

    .PARAMETER shareId
        The ID of the NFS Share to be used by the client

    .PARAMETER Permission
        The permission of the client on the share. Default is "read-only"

    .PARAMETER accessKrb5
        The permission of the client on the share. Default is "no-permission"

    .PARAMETER accessKrb5i
        The permission of the client on the share. Default is "no-permission"

    .PARAMETER accessKrb5p
        The permission of the client on the share. Default is "no-permission"

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
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [string]$clientName,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
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
                    $deviceManager
                }
                (Get-DMShare -WebSession $session -ShareType NFS).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$shareId,
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("read-only", "read-write", "no-permission")]
        [string]$Permission = "read-only",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("read-only", "read-write", "no-permission")]
        [string]$accessKrb5 = "no-permission",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("read-only", "read-write", "no-permission")]
        [string]$accessKrb5i = "no-permission",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("read-only", "read-write", "no-permission")]
        [string]$accessKrb5p = "no-permission",
        #[Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        #    [ValidateSet("synchronous","asynchronous")]
        #    [string]$writeMode = "no-permission",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("all_squash", "no_all_squash")]
        [string]$permissionContraint = "no_all_squash",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("root_squash", "no_root_squash")]
        [string]$rootPermissionConstraint = "root_squash",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [ValidateSet("enabled", "disabled")]
        [string]$sourcePortVerify = "disabled",
        [Parameter(ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0, Mandatory = $false)]
        [Int16]$vStoreId
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
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
    switch ($accessKrb5) {
        "read-only" {
            $Krb5Access = 0
        }
        "read-write" {
            $Krb5Access = 1
        }
        "no-permission" {
            $Krb5Access = 5
        }
    }
    switch ($accessKrb5i) {
        "read-only" {
            $Krb5iAccess = 0
        }
        "read-write" {
            $Krb5iAccess = 1
        }
        "no-permission" {
            $Krb5iAccess = 5
        }
    }
    switch ($accessKrb5p) {
        "read-only" {
            $Krb5pAccess = 0
        }
        "read-write" {
            $Krb5pAccess = 1
        }
        "no-permission" {
            $Krb5pAccess = 5
        }
    }

    #switch ($writeMode){
    #    "synchronous" {$writeMode = 0}
    #    "asynchronous" {$writeMode = 1}
    #}

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
        #ACCESSKRB5 = $Krb5Access;
        #ACCESSKRB5I = $Krb5iAccess;
        #ACCESSKRB5P = $Krb5pAccess;
        ALLSQUASH  = $allsquash;
        ROOTSQUASH = $rootSquash;
        SECURE     = $secure;
    }

    if ($vStoreId) {
        $body.Add("vstoreId", $vStoreId)
    }

    if ($PSCmdlet.ShouldProcess($clientName, 'Create NFS client')) {
        $response = Invoke-DeviceManager -WebSession $session -Method "POST" -Resource "NFS_SHARE_AUTH_CLIENT" -BodyData $body

        if ($response.error.Code -eq 0) {
            $result = [OceanstorNFSclient]::new($response.data, $session)
        }
        else {
            $result = $response.error
        }

        return $result.Id
    }
}
