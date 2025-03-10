function new-DMnfsShare{
	<#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage NFS Share (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage NFS Share (requires the NAS License)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage NFS Share (requires the NAS License)

	.EXAMPLE

		PS C:\> new-DMnfsShare -webSession $session

		OR

		PS C:\> new-DMnfsShare

	.NOTES
		Filename: new-DMnfsShare.ps1
		Author: Joao Carmona
		Modified date: 2025-03-10
		Version 0.1

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [string]$sharepath,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$true)]
        [string]$FileSystemId,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [ValidateSet("UTF-8")]
        [string]$encoding = "UTF-8",
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [string]$dTree,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [ValidateSet("normal share","Private share")]
        [string]$privateShare = "normal share"
    )

    if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    switch ($encoding){
        "UTF-8" {$characterEncoding = 0}
    }

    switch ($privateShare){
        "normal share" {$sharePrivate = 0}
        "private share" {$sharePrivate = 1}
    }

    $body = @{
        SHAREPATH = $sharepath;
        FSID = $FileSystemId;
        #CHARACTERENCODING = $characterEncoding;
        #sharePrivate = $sharePrivate;
    }   

    if ($dTree){
        $body.Add("DTREEID",$dTree)
    }
    
    $response = invoke-DeviceManager -WebSession $session -Method "POST" -Resource "NFSSHARE" -BodyData $body

    return $response
}