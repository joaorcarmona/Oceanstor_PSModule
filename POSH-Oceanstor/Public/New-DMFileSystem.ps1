function New-DMFileSystem {
    <#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage Filesystem (requires the NAS License)

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage FileSystem (requires the NAS license)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER FileSystemName
        Name of the FileSystem to be created

    .PARAMETER StoragePoolID
        ID of the Storage Pool where the FileSystem will be created

    .PARAMETER description
        Description of the FileSystem to be created

    .PARAMETER Worm
        If the FileSystem is a WORM FileSystem  (Write Once Read Many)

    .PARAMETER capacity
        Capacity of the FileSystem to be created.
        Specify a size with an MB, GB, or TB suffix, for example 100MB, 10GB, 1.5TB, or 1,5TB.
        Both a period and a comma are accepted as the decimal separator. Unit suffixes are case-insensitive
        and use binary units (1MB = 1024^2 bytes). For backward compatibility, an integer without a suffix
        is treated as a number of gigabytes.

    .PARAMETER snapShotReserve
        Percentage of the FileSystem capacity to be reserved for Snapshots  (default 20%)

    .PARAMETER autoDeleteSnap
        If the Snapshots will be automatically deleted  (default false)

    .PARAMETER AlarmThresold
        Alarm threshold for the file system capacity. The parameter name is kept as AlarmThresold for compatibility. Default is 90%.

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
		System.Management.Automation.PSCustomObject
		System.String
		System.Int64
		System.Boolean

		You can pipe an OceanStor session object to WebSession and provide file system creation values by property name.

	.OUTPUTS
		OceanstorFileSystem
		System.Management.Automation.PSCustomObject

		Returns the created file system object on success, or the OceanStor API error object on failure.

	.EXAMPLE

		PS C:\> New-DMFileSystem -WebSession $session -FileSystemName 'documents' -StoragePoolID 0 -Capacity 100MB

		OR

		PS C:\> New-DMFileSystem -WebSession $session -FileSystemName 'archive' -StoragePoolID 0 -Capacity '1,5TB'

	.NOTES
		Filename: New-DMFileSystem.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 1, Mandatory = $true)]
        [string]$FileSystemName,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 2, Mandatory = $true)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                $storagePools = @(Get-DMstoragePool -WebSession $session)
                if ($storagePools.Id -contains $_) {
                    return $true
                }
                throw "Invalid StoragePoolID. Valid values are: $($storagePools.Id -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMstoragePool -WebSession $session).Id | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [Int16]$StoragePoolID,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [string]$description,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$Worm = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [object]$capacity,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [Int32]$snapShotReserve = 20,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [string]$autoDeleteSnap = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [int64]$AlarmThresold = 90,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [ValidateSet("database", "VM", "user-defined")]
        [string]$usage = "user-defined",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$checkSumEnable = $true,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$accessTime = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [ValidateSet("Hourly", "Daily", "disabled")]
        [string]$accessTimeUpdateMode = "disabled",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$readOnly = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [ValidateSet("low", "medium", "high")]
        [string]$FileSystemIOpriority = "low",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$Compression = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [ValidateSet("rapid", "deep")]
        [string]$CompressionAlgorithm = "rapid",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$Dedupe = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Mandatory = $false)]
        [bool]$Autogrow = $false
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $script:CurrentOceanstorSession
    }

    switch ($usage) {
        "database" {
            $applicationscenario = 1
        }
        "VM" {
            $applicationscenario = 2
        }
        "user-defined" {
            $applicationscenario = 3
        }
    }

    switch ($FileSystemIOpriority) {
        "low" {
            $ioPriority = 1
        }
        "medium" {
            $ioPriority = 2
        }
        "high" {
            $ioPriority = 3
        }
    }

    switch ($CompressionAlgorithm) {
        "rapid" {
            $algoritmCompression = 0
        }
        "deep" {
            $algoritmCompression = 1
        }
    }

    switch ($accessTimeUpdateMode) {
        "disabled" {
            $atimeupdatemode = 4294967295
        }
        "Hourly" {
            $atimeupdatemode = 3600
        }
        "Daily" {
            $atimeupdatemode = 86400
        }
    }

    $capacityInBlocks = $null
    if ($PSBoundParameters.ContainsKey('capacity')) {
        $capacityInBlocks = ConvertTo-DMCapacityBlock -Capacity $capacity -UnitlessUnit GB
    }

    $body = @{
        NAME                  = $FileSystemName;
        PARENTTYPE            = 216;
        PARENTID              = $StoragePoolID;
        ALLOCTYPE             = 1;
        SUBTYPE               = $Worm;
        SNAPSHOTRESERVEPER    = $snapShotReserve;
        AUTODELSNAPSHOTENABLE = $autoDeleteSnap;
        CAPACITYTHRESOLD      = $AlarmThresold;
        APPLICATIONSCENARIO   = $applicationscenario;
        CHECKSUMENABLE        = $checkSumEnable;
        ATIME                 = $accessTime;
        ATIMEUPDATEMODE       = $atimeupdatemode;
        READONLY              = $readOnly;
        IOPRIORITY            = $ioPriority;
        ENABLECOMPRESSION     = $Compression;
        COMPRESSION           = $algoritmCompression
    }

    if ($description) {
        $body.Add("DESCRIPTION", $description)
    }

    if ($null -ne $capacityInBlocks) {
        $body.Add("CAPACITY", $capacityInBlocks)
    }

    if ($PSCmdlet.ShouldProcess($FileSystemName, 'Create file system')) {
        $response = Invoke-DeviceManager -WebSession $session -Method "POST" -Resource "filesystem" -BodyData $body

        if ($response.error.Code -eq 0) {
            $result = [OceanstorFileSystem]::new($response.data, $session)
        }
        else {
            $result = $response.error
        }

        return $result
    }
}
