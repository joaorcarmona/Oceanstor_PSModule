<#
.SYNOPSIS
    Creates a Fibre Channel initiator in the OceanStor system.

.DESCRIPTION
    Adds a Fibre Channel initiator WWN to the storage system and can optionally associate the initiator with an existing host.
    Third-party multipath settings can be supplied when the initiator requires explicit path and failover configuration.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER WWN
    Fibre Channel WWN of the initiator to create. The value must contain 16 hexadecimal characters and cannot be all zeros or all Fs.

.PARAMETER Name
    Optional friendly name for the initiator. The value must be 1 to 31 characters and may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER HostName
    Optional host name to associate the initiator with. The name is validated against existing OceanStor hosts.

.PARAMETER Multipath
    Multipath type for the initiator. Use Default for OceanStor default multipathing or ThirdParty to send explicit path and failover options.

.PARAMETER PathType
    Path preference used when Multipath is ThirdParty. Valid values are Preferred and NonPreferred.

.PARAMETER FailoverMode
    ALUA failover mode used when Multipath is ThirdParty. Valid values are EarlyALUA, CommonALUA, NoALUA, and SpecialALUA.

.PARAMETER SpecialModeType
    Special ALUA mode type used when FailoverMode is SpecialALUA. Valid values are 0 through 3.

.PARAMETER VstoreId
    Optional vStore ID used to scope the initiator operation.

.INPUTS
    System.Management.Automation.PSCustomObject

.OUTPUTS
    OceanstorHostinitiatorFC
    Returns the created Fibre Channel initiator object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMFiberChannelInitiator -WWN '5001438000000001' -Name 'fc-01'

    Creates a Fibre Channel initiator with a friendly name.

.EXAMPLE
    PS> New-DMFiberChannelInitiator -WWN '5001438000000002' -HostName 'host01' -Multipath ThirdParty -PathType Preferred -FailoverMode CommonALUA

    Creates a Fibre Channel initiator, associates it with host01, and applies third-party multipath settings.

.NOTES
    Filename: New-DMFiberChannelInitiator.ps1
#>
function New-DMFiberChannelInitiator {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
                if (Test-WWNAddress -WWN $_) {
                    return $true
                }
                throw 'WWN must contain 16 hexadecimal characters and cannot be all zeros or all Fs.'
            })]
        [string]$WWN,

        [ValidatePattern('^[A-Za-z0-9_.-]{1,31}$')]
        [string]$Name,

        [ValidateScript({
                $candidate = $_
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $hosts = @(Get-DMhost -WebSession $session)
                $matchingItems = @($hosts | Where-Object Name -EQ $candidate)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "HostName is ambiguous because more than one host is named '$candidate'."
                }
                throw "Invalid HostName. Valid values are: $($hosts.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (Get-DMhost -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [ValidateSet('Default', 'ThirdParty')]
        [string]$Multipath = 'Default',

        [ValidateSet('Preferred', 'NonPreferred')]
        [string]$PathType = 'Preferred',

        [ValidateSet('EarlyALUA', 'CommonALUA', 'NoALUA', 'SpecialALUA')]
        [string]$FailoverMode = 'CommonALUA',

        [ValidateRange(0, 3)]
        [int]$SpecialModeType,

        [string]$VstoreId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{
        ID            = $WWN
        MULTIPATHTYPE = @{ Default = 0; ThirdParty = 1 }[$Multipath]
    }
    if ($Name) {
        $body.NAME = $Name
    }
    if ($HostName) {
        $hostObject = @(Get-DMhost -WebSession $session | Where-Object Name -EQ $HostName)[0]
        $body.PARENTTYPE = 21
        $body.PARENTID = $hostObject.Id
    }
    if ($Multipath -eq 'ThirdParty') {
        $body.PATHTYPE = @{ Preferred = 0; NonPreferred = 1 }[$PathType]
        $body.FAILOVERMODE = @{ EarlyALUA = 0; CommonALUA = 1; NoALUA = 2; SpecialALUA = 3 }[$FailoverMode]
        if ($FailoverMode -eq 'SpecialALUA') {
            $body.SPECIALMODETYPE = $SpecialModeType
        }
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'fc_initiator' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorHostinitiatorFC]::new($response.data, $session)
    }
    return $response.error
}
