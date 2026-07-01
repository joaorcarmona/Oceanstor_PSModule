function New-DMLun {
    <#
	.SYNOPSIS
		To Create a Huawei Oceanstor Storage LUN

	.DESCRIPTION
		Function to create a Huawei Oceanstor Storage LUN (Logical Unit Number)

	.PARAMETER webSession
		Optional parameter to define the session to be use on the REST call. If not defined, the "deviceManager" Global Variable will be used

    .PARAMETER LunName
        Mandatory parameter. Name of the LUN to be created

    .PARAMETER StoragePoolID
        Mandatory parameter. ID of the Storage Pool where the LUN will be created.
        Valid values are dynamically generated from the output of Get-DMstoragePool and support tab-completion.
    .PARAMETER capacity
        Mandatory parameter. Capacity of the LUN to be created.
        Specify a size with an MB, GB, or TB suffix, for example 10MB, 10GB, 1.5TB, or 1,5TB.
        Both a period and a comma are accepted as the decimal separator.
        Unit suffixes are case-insensitive and use binary units (1MB = 1024^2 bytes).
        For backward compatibility, an integer without a suffix is treated as a raw count of 512-byte blocks.

    .PARAMETER description
        Optional parameter. Description of the LUN to be created

    .PARAMETER sectorSize
        Optional parameter. Sector size of the LUN (512 or 4096). Default is 512

    .PARAMETER allocType
        Optional parameter. Allocation type of the LUN. Valid values: "Thin", "Thick". Default is "Thick"

    .PARAMETER IoPriority
        Optional parameter. IO priority level. Valid values: "Low", "Medium", "High". Default is "Low"

    .PARAMETER enableCompression
        Optional parameter. Enable compression on the LUN. Default is $false

    .PARAMETER enableDeduplication
        Optional parameter. Enable deduplication on the LUN. Default is $false

    .PARAMETER enableSmartTier
        Optional parameter. Enable SmartTier on the LUN. Default is $false

    .PARAMETER workloadTypeId
        Optional parameter. Workload type ID for the LUN

    .PARAMETER EnableCache
        Optional parameter. Enable cache for the LUN. Default is $true

    .PARAMETER writeCachePolicy
        Optional parameter. Write cache policy. Valid values: "WriteBack", "WriteThrough". Default is "WriteBack"

    .PARAMETER readCachePolicy
        Optional parameter. Read cache policy. Valid values: "ReadAhead", "NoReadAhead". Default is "ReadAhead"

    .PARAMETER prefetchPolicy
        Optional parameter. Prefetch policy. Valid values: "Intelligent", "Fixed", "Disabled". Default is "Intelligent"

    .PARAMETER mirrorPolicy
        Optional parameter. Mirror policy. Valid values: "Linear", "Mirror". Default is "Linear"

	.INPUTS
		System.Management.Automation.PSCustomObject
		System.String
		System.Int64
		System.Boolean

		You can pipe an OceanStor session object to WebSession and provide LUN creation values by property name.

	.OUTPUTS
		OceanstorLunv3
		OceanstorLunv6
		System.Management.Automation.PSCustomObject

		Returns the created LUN object on success, or the OceanStor API error object on failure. The LUN class depends on the connected OceanStor version.

	.EXAMPLE

		PS C:\> New-DMLun -LunName "MyLUN" -StoragePoolID "0" -Capacity 512MB

		OR

		PS C:\> New-DMLun -WebSession $session -LunName "TestLUN" -StoragePoolID "1" -Capacity 1GB -AllocType "Thin" -EnableCompression $true

	.NOTES
		Filename: New-DMLun.ps1

	.LINK
	#>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true)]

    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0, Mandatory = $false)]
        [pscustomobject]$WebSession,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 1, Mandatory = $true)]
        [string]$LunName,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 2, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object]$capacity,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 3, Mandatory = $true)]
        [ValidateScript({
                # Validate that the StoragePoolID exists by checking against existing storage pools
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $deviceManager
                }
                $storagePools = Get-DMstoragePool -WebSession $session
                if ($storagePools.Id -contains $_) {
                    $true
                }
                else {
                    throw "Invalid StoragePoolID. Valid values are: $($storagePools.Id -join ', ')"
                }
            })]

        [ArgumentCompleter({
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

                [CmdletBinding(SupportsShouldProcess = $true)]

                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                if ($WebSession) {
                    $session = $WebSession
                }
                else {
                    $session = $deviceManager
                }
                (Get-DMstoragePool -WebSession $session).Id | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$StoragePoolID,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 4, Mandatory = $false)]
        [string]$description,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 5, Mandatory = $false)]
        [ValidateSet(512, 4096)]
        [int]$sectorSize = 512,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 6, Mandatory = $false)]
        [ValidateSet("Thin", "Thick")]
        [string]$allocType = "Thick",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 7, Mandatory = $false)]
        [ValidateSet("Low", "Medium", "High")]
        [string]$IoPriority = "Low",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 8, Mandatory = $false)]
        [bool]$enableCompression = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 9, Mandatory = $false)]
        [bool]$enableDeduplication = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 10, Mandatory = $false)]
        [bool]$enableSmartTier = $false,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 11, Mandatory = $false)]
        [string]$workloadTypeId,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 12, Mandatory = $false)]
        [bool]$EnableCache = $true,
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 13, Mandatory = $false)]
        [ValidateSet("WriteBack", "WriteThrough")]
        [string]$writeCachePolicy = "WriteBack",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 14, Mandatory = $false)]
        [ValidateSet("ReadAhead", "NoReadAhead")]
        [string]$readCachePolicy = "ReadAhead",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 15, Mandatory = $false)]
        [ValidateSet("Intelligent", "Fixed", "Disabled")]
        [string]$prefetchPolicy = "Intelligent",
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 16, Mandatory = $false)]
        [ValidateSet("Linear", "Mirror")]
        [string]$mirrorPolicy = "Linear"
    )

    if ($WebSession) {
        $session = $WebSession
    }
    else {
        $session = $deviceManager
    }

    # ensure dynamic StoragePoolID is assigned to variable for later use
    if ($PSBoundParameters.ContainsKey('StoragePoolID')) {
        $StoragePoolID = $PSBoundParameters['StoragePoolID']
    }

    $capacityInBlocks = ConvertTo-DMCapacityBlock -Capacity $capacity -UnitlessUnit Blocks

    # Convert allocation type to Huawei API value
    switch ($allocType) {
        "Thin" {
            $allocationType = 1
        }
        "Thick" {
            $allocationType = 0
        }
    }

    # Convert IO Priority to Huawei API value
    switch ($IoPriority) {
        "Low" {
            $ioPriorityValue = 1
        }
        "Medium" {
            $ioPriorityValue = 2
        }
        "High" {
            $ioPriorityValue = 3
        }
    }

    # Convert Write Cache Policy to Huawei API value
    switch ($writeCachePolicy) {
        "WriteBack" {
            $writeCachePolicyValue = 1
        }
        "WriteThrough" {
            $writeCachePolicyValue = 0
        }
    }

    # Convert Read Cache Policy to Huawei API value
    switch ($readCachePolicy) {
        "ReadAhead" {
            $readCachePolicyValue = 1
        }
        "NoReadAhead" {
            $readCachePolicyValue = 0
        }
    }

    # Convert Prefetch Policy to Huawei API value
    switch ($prefetchPolicy) {
        "Intelligent" {
            $prefetchPolicyValue = 0
        }
        "Fixed" {
            $prefetchPolicyValue = 1
        }
        "Disabled" {
            $prefetchPolicyValue = 2
        }
    }

    # Convert Mirror Policy to Huawei API value
    switch ($mirrorPolicy) {
        "Linear" {
            $mirrorPolicyValue = 0
        }
        "Mirror" {
            $mirrorPolicyValue = 1
        }
    }

    # Build the request body
    $body = @{
        NAME            = $LunName;
        PARENTID        = $StoragePoolID;
        CAPACITY        = $capacityInBlocks;
        SECTORSIZE      = $sectorSize;
        ALLOCTYPE       = $allocationType;
        IOPRIORITY      = $ioPriorityValue;
        COMPRESSION     = [int]$enableCompression;
        DEDUPLICATION   = [int]$enableDeduplication;
        SMARTTIER       = [int]$enableSmartTier;
        CACHETPOLICY    = $writeCachePolicyValue;
        READCACHEPOLICY = $readCachePolicyValue;
        PREFETCHPOLICY  = $prefetchPolicyValue;
        MIRRORMULTIPLEX = $mirrorPolicyValue;
        ENABLE_CACHE    = [int]$EnableCache;
    }

    # Add optional parameters if provided
    if ($description) {
        $body.Add("DESCRIPTION", $description)
    }

    if ($workloadTypeId) {
        $body.Add("WORKLOADTYPEID", $workloadTypeId)
    }

    if ($PSCmdlet.ShouldProcess($LunName, 'Create LUN')) {
        # Make the REST API call
        $response = Invoke-DeviceManager -WebSession $session -Method "POST" -Resource "lun" -BodyData $body

        # Check if the operation was successful and create the appropriate object
        if ($response.error.Code -eq 0) {
            # Determine the correct LUN class based on device version
            $storageVersion = $session.version.Substring(0, 2)

            if ($storageVersion -eq "V6") {
                $LunObjectClass = "OceanstorLunv6"
            }
            else {
                $LunObjectClass = "OceanstorLunv3"
            }

            # Create the LUN object from the response
            $result = New-Object -TypeName $LunObjectClass -ArgumentList @($response.data, $session)
        }
        else {
            $result = $response.error
        }

        return $result
    }
}
