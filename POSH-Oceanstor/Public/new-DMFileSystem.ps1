function new-DMFileSystem{
	<#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage Filesystem (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage FileSystem (requires the NAS license)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used
    
    .PARAMETER FileSystemName
        Name of the FileSystem to be created
    
    .PARAMETER StoragePoolID
        ID of the Storage Pool where the FileSystem will be created 

    .PARAMETER description
        Description of the FileSystem to be created
    
    .PARAMETER Worm
        If the FileSystem is a WORM FileSystem  (Write Once Read Many)
    
    .PARAMETER capacity
        Capacity of the FileSystem to be created (in gigabytes)
    
    .PARAMETER snapShotReserve
        Percentage of the FileSystem capacity to be reserved for Snapshots  (default 20%)
    
    .PARAMETER autoDeleteSnap
        If the Snapshots will be automatically deleted  (default false)
    
    .PARAMETER AlarmThresold
        Alarm Thresold for the FileSystem capacity  (default 90%)   
    
    .PARAMETER usage
        Usage of the FileSystem (database, VM, user-defined)  (default user-defined)
    
    .PARAMETER checkSumEnable
        If the Checksum is enabled on the FileSystem  (default true) 
    
    .PARAMETER accessTime
        If the Access Time is enabled on the FileSystem  (default false)
    
    .PARAMETER accessTimeUpdateMode
        Mode of the Access Time Update (Hourly, Daily, disabled)  (default disabled)
    
    .PARAMETER readOnly
        If the FileSystem is Read Only  (default false)
    
    .PARAMETER FileSystemIOpriority
        Priority of the FileSystem IO (low, medium, high)  (default low)
    
    .PARAMETER Compression  
        If the Compression is enabled on the FileSystem  (default false)
    
    .PARAMETER CompressionAlgorithm
        Algorithm of the Compression (rapid, deep)  (default rapid)
    
    .PARAMETER Dedupe        
        If the Deduplication is enabled on the FileSystem  (default false)
    
    .PARAMETER Autogrow
        If the FileSystem is Autogrow  (default false) 

	.INPUTS

	.OUTPUTS
		returns the Huawei Oceanstor Storage FileSystem created

	.EXAMPLE

		PS C:\> new-DMFileSystem -webSession $session

		OR

		PS C:\> new-DMFileSystem

	.NOTES
		Filename: new-DMFileSystem.ps1
		Author: Joao Carmona
		Modified date: 2025-03-10
		Version 0.1

	.LINK
	#>
	[Cmdletbinding()]
    Param(
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0,Mandatory=$false)]
        [pscustomobject]$WebSession,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$true)]
        [string]$FileSystemName,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$true)]
        [Int16]$StoragePoolID,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [string]$description,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$Worm=$false,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [Int64]$capacity,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [Int32]$snapShotReserve=20,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [string]$autoDeleteSnap=$false,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [int64]$AlarmThresold=90,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("database","VM","user-defined")]
        [string]$usage = "user-defined",
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$checkSumEnable=$true, 
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$accessTime=$false,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("Hourly","Daily","disabled")]
        [string]$accessTimeUpdateMode="disabled",
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$readOnly=$false,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("low","medium","high")]
        [string]$FileSystemIOpriority = "low",
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$Compression = $false,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [ValidateSet("rapid","deep")]
        [string]$CompressionAlgorithm = "rapid",
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$Dedupe = $false,
    [Parameter(ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$false,Position=0,Mandatory=$false)]
        [bool]$Autogrow = $false
	)

	if ($WebSession){
        $session = $WebSession
    } else {
        $session = $deviceManager
    }

    switch ($usage){
        "database" {$applicationscenario = 1}
        "VM" {$applicationscenario = 2}
        "user-defined" {$applicationscenario = 3}
    }

    switch ($FileSystemIOpriority){
        "low" {$ioPriority = 1}
        "medium" {$ioPriority = 2}
        "high" {$ioPriority = 3}
    }

    switch ($CompressionAlgorithm){
        "rapid" {$algoritmCompression = 0}
        "deep" {$algoritmCompression = 1}
    }

    switch ($accessTimeUpdateMode){
        "disabled" {$atimeupdatemode = 4294967295}
        "Hourly" {$atimeupdatemode = 3600}
        "Daily" {$atimeupdatemode = 86400}
    }

    $body = @{
            NAME = $FileSystemName;
            PARENTTYPE = 216;
            PARENTID = $StoragePoolID;
            ALLOCTYPE = 1;
            SUBTYPE = $Worm;
            SNAPSHOTRESERVEPER = $snapShotReserve;
            AUTODELSNAPSHOTENABLE = $autoDeleteSnap;
            CAPACITYTHRESOLD = $AlarmThresold;
            APPLICATIONSCENARIO = $applicationscenario;
            CHECKSUMENABLE = $checkSumEnable;
            ATIME = $accessTime;
            ATIMEUPDATEMODE = $atimeupdatemode;
            READONLY = $readOnly;
            IOPRIORITY = $ioPriority;
            ENABLECOMPRESSION = $Compression;
            COMPRESSION = $algoritmCompression
    }

    if ($description){
        $body.Add("DESCRIPTION",$description)
    }

    if ($capacity){
        $fcapacity = [math]::Round($capacity / 512 * 1GB)
        $body.Add("CAPACITY",$fcapacity)
    }

    $response = invoke-DeviceManager -WebSession $session -Method "POST" -Resource "filesystem" -BodyData $body

    if ($response.error.Code -eq 0){
        $result = [OceanstorFileSystem]::new($response.data)
    } else {
        $result = $response.error
    }

    return $result
}