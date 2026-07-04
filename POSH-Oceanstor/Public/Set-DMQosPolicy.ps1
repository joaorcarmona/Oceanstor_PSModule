function Set-DMQosPolicy {
    <#
    .SYNOPSIS
        Modifies a Huawei Oceanstor SmartQoS policy.

    .DESCRIPTION
        Modifies a SmartQoS policy via the ioclass resource, using New-DMNamedObjectUpdate to
        build the request body. ioclass is not an ApiV2 resource, so Invoke-DeviceManager is
        called without -ApiV2.

    .PARAMETER WebSession
        Optional parameter to define the session to be use on the REST call. If not defined, the module's cached $script:CurrentOceanstorSession session will be used

    .PARAMETER Name
        Name of the SmartQoS policy to modify. Mutually exclusive with Id (enforced by parameter set).

    .PARAMETER Id
        ID of the SmartQoS policy to modify. Mutually exclusive with Name (enforced by parameter set).

    .PARAMETER NewName
        New name for the policy.

    .PARAMETER Description
        New description for the policy.

    .PARAMETER MaxBandwidth
        New maximum bandwidth in MB/s (1-999,999,999).

    .PARAMETER MaxIOPS
        New maximum IOPS (100-999,999,999).

    .PARAMETER MinBandwidth
        New minimum bandwidth in MB/s (1-999,999,999).

    .PARAMETER MinIOPS
        New minimum IOPS (100-999,999,999).

    .PARAMETER Latency
        New I/O latency target in microseconds: 500 or 1500.

    .PARAMETER BurstBandwidth
        New maximum burst bandwidth in MB/s. Requires BurstTime.

    .PARAMETER BurstIOPS
        New maximum burst IOPS. Requires BurstTime.

    .PARAMETER BurstTime
        New burst time in seconds (1-999,999,999). Mandatory when BurstBandwidth or BurstIOPS is specified.

    .PARAMETER Priority
        New priority: Normal or High.

    .PARAMETER VstoreId
        Optional vStore ID.

    .INPUTS
        System.Management.Automation.PSCustomObject

    .OUTPUTS
        System.Object

    .EXAMPLE
        PS> Set-DMQosPolicy -Name 'qos01' -MaxIOPS 8000

    .EXAMPLE
        PS> Set-DMQosPolicy -Id '1' -NewName 'qos01-renamed' -Description 'updated'

    .NOTES
        Filename: Set-DMQosPolicy.ps1
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByName', ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $script:CurrentOceanstorSession
                }
                (Get-DMQosPolicy -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'ById', ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
                $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }
                $matchingItems = @(Get-DMQosPolicy -WebSession $session -Id $_)
                if ($matchingItems.Count -eq 1) { return $true }
                throw 'Invalid Id.'
            })]
        [string]$Id,

        [ValidateLength(1, 31)][ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$NewName,
        [AllowEmptyString()][ValidateLength(0, 255)][string]$Description,

        [ValidateRange(1, 999999999)]
        [uint32]$MaxBandwidth,

        [ValidateRange(100, 999999999)]
        [uint32]$MaxIOPS,

        [ValidateRange(1, 999999999)]
        [uint32]$MinBandwidth,

        [ValidateRange(100, 999999999)]
        [uint32]$MinIOPS,

        [ValidateSet(500, 1500)]
        [uint32]$Latency,

        [ValidateRange(1, 999999999)]
        [uint32]$BurstBandwidth,

        [ValidateRange(100, 999999999)]
        [uint32]$BurstIOPS,

        [ValidateRange(1, 999999999)]
        [uint32]$BurstTime,

        [ValidateSet('Normal', 'High')]
        [string]$Priority,

        [string]$VstoreId
    )

    process {
        try {
            $session = if ($WebSession) { $WebSession } else { $script:CurrentOceanstorSession }

            if (($PSBoundParameters.ContainsKey('BurstBandwidth') -or $PSBoundParameters.ContainsKey('BurstIOPS')) -and -not $PSBoundParameters.ContainsKey('BurstTime')) {
                throw 'BurstTime is mandatory when BurstBandwidth or BurstIOPS is specified.'
            }

            if ($PSCmdlet.ParameterSetName -eq 'ById') {
                $resolved = @(Get-DMQosPolicy -WebSession $session -Id $Id)[0]
                if ($null -eq $resolved) { throw "Could not resolve 'Id' - the object may have been removed since parameter validation." }
                $currentName = $resolved.Name
            }
            else {
                $currentName = $Name
            }

            $apiProperties = @{}
            if ($PSBoundParameters.ContainsKey('MaxBandwidth')) { $apiProperties.MAXBANDWIDTH = $MaxBandwidth }
            if ($PSBoundParameters.ContainsKey('MaxIOPS')) { $apiProperties.MAXIOPS = $MaxIOPS }
            if ($PSBoundParameters.ContainsKey('MinBandwidth')) { $apiProperties.MINBANDWIDTH = $MinBandwidth }
            if ($PSBoundParameters.ContainsKey('MinIOPS')) { $apiProperties.MINIOPS = $MinIOPS }
            if ($PSBoundParameters.ContainsKey('Latency')) { $apiProperties.LATENCY = $Latency }
            if ($PSBoundParameters.ContainsKey('BurstBandwidth')) { $apiProperties.BURSTBANDWIDTH = $BurstBandwidth }
            if ($PSBoundParameters.ContainsKey('BurstIOPS')) { $apiProperties.BURSTIOPS = $BurstIOPS }
            if ($PSBoundParameters.ContainsKey('BurstTime')) { $apiProperties.BURSTTIME = $BurstTime }
            if ($PSBoundParameters.ContainsKey('Priority')) { $apiProperties.PRIORITY = switch ($Priority) { 'Normal' { 0 }; 'High' { 1 } } }

            $update = New-DMNamedObjectUpdate -Objects @(Get-DMQosPolicy -WebSession $session) `
                -CurrentName $currentName -EntityName 'SmartQoS policy' -ResourceBase 'ioclass' -NewName $NewName `
                -NewNameSpecified:$($PSBoundParameters.ContainsKey('NewName')) -Description $Description `
                -DescriptionSpecified:$($PSBoundParameters.ContainsKey('Description')) -ApiProperties $apiProperties `
                -VstoreId $VstoreId

            if ($PSCmdlet.ShouldProcess($currentName, $update.Action)) {
                $response = Invoke-DeviceManager -WebSession $session -Method 'PUT' -Resource $update.Resource -BodyData $update.Body
                $response = $response | Assert-DMApiSuccess
                return $response.error
            }
        }
        catch {
            $PSCmdlet.WriteError($_)
        }
    }
}
