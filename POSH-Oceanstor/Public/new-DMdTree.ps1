function new-DMdTree{
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

	.OUTPUTS
		returns the Huawei Oceanstor Storage FileSystem created

	.EXAMPLE

		PS C:\> new-DMdTree -webSession $session -dTreeName "dTree1" -FileSystemId 150

		OR

		PS C:\> new-DMdTree -dTreeName "dTree1" -FileSystemId 150

	.NOTES
		Filename: new-DMFileSystem.ps1
		Author: Joao Carmona
		Modified date: 2025-03-12
		Version 0.1

	.LINK
	#>
	[Cmdletbinding(DefaultParameterSetName = 'byId')]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
    [pscustomobject]$WebSession,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=1,Mandatory=$true)]
        [string]$dTreeName,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=2,Mandatory=$true,ParameterSetName = "byName")]
        [string]$fileSystemName,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$true,ParameterSetName = "byId")]
        [string]$fileSystemId,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("enabled","disabled")]
        [string]$quotaSwitch = "disabled",
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [string]$vStoreId,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [string]$path,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("Native","NTFS","UNIX","Mixed")]
        [string]$securityStyle,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("Mandatory","Advisory")]
        [string]$lockingPolicy="Mandatory"
    )

    if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    $body = @{
        NAME = $dTreeName;
        PARENTTYPE = 40;
        QUOTASWITCH = $quotaSwitch
        path = $path
        nasLockingPolicy = $lockingPolicy
    }

    if ($vStoreId){
        $body.Add("vstoreId",$vStoreId)
    }

    if($fileSystemId){
        $body.Add("PARENTID",$fileSystemId)
    } else {
        $body.Add("PARENTNAME",$fileSystemName)
    }

    if($securityStyle){
        switch ($securityStyle){
            "Native" {$body.Add("securityStyle",1)}
            "NTFS" {$body.Add("securityStyle",2)}
            "UNIX" {$body.Add("securityStyle",3)}
            "Mixed" {$body.Add("securityStyle",4)}
        }
    }

    $response = invoke-DeviceManager -WebSession $session -Method "POST" -Resource "QUOTATREE" -BodyData $body

    if ($response.error.Code -eq 0){
        $result = $response.data
    } else {
        $result = $response.error
    }

    return $result
}





