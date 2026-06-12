<#
.SYNOPSIS
    Creates an iSCSI initiator in the OceanStor system.

.DESCRIPTION
    Adds an iSCSI initiator identifier to the storage system and can optionally associate the initiator with an existing host.
    CHAP and third-party multipath settings can be supplied when the host configuration requires them.

.PARAMETER WebSession
    Optional session object returned by Connect-deviceManager. When omitted, the global deviceManager session is used.

.PARAMETER Identifier
    iSCSI initiator identifier to create, such as an IQN.

.PARAMETER Name
    Optional friendly name for the initiator. The value must be 1 to 31 characters and may contain letters, numbers, underscores, periods, or hyphens.

.PARAMETER HostName
    Optional host name to associate the initiator with. The name is validated against existing OceanStor hosts.

.PARAMETER UseChap
    Enables CHAP authentication for the initiator. When specified, ChapName and ChapPassword are required.

.PARAMETER ChapName
    CHAP user name for the initiator. Required when UseChap is specified.

.PARAMETER ChapPassword
    CHAP password for the initiator. Required when UseChap is specified and must be 12 to 16 characters.

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
    OceanstorHostinitiatorISCSI
    Returns the created iSCSI initiator object on success, or the API error object on failure.

.EXAMPLE
    PS> New-DMIscsiInitiator -Identifier 'iqn.2026-06.test:host01' -Name 'iscsi-01'

    Creates an iSCSI initiator with a friendly name.

.EXAMPLE
    PS> New-DMIscsiInitiator -Identifier 'iqn.2026-06.test:host02' -HostName 'host02' -UseChap -ChapName 'host02chap' -ChapPassword 'Secret123456'

    Creates an iSCSI initiator, associates it with host02, and enables CHAP authentication.

.NOTES
    Filename: New-DMIscsiInitiator.ps1
#>
function New-DMIscsiInitiator {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidatePattern('^[A-Za-z0-9][\x21-\x7e]{0,222}$')]
        [string]$Identifier,

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
                $hosts = @(Get-DMhosts -WebSession $session)
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
                (Get-DMhosts -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$HostName,

        [switch]$UseChap,

        [ValidatePattern('^[A-Za-z0-9][\x21-\x7e]{3,222}$')]
        [string]$ChapName,

        [ValidateLength(12, 16)]
        [string]$ChapPassword,

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

    if ($UseChap -and (-not $ChapName -or -not $ChapPassword)) {
        throw 'ChapName and ChapPassword are mandatory when UseChap is specified.'
    }

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $body = @{
        ID            = $Identifier
        USECHAP       = $UseChap.IsPresent
        MULTIPATHTYPE = @{ Default = 0; ThirdParty = 1 }[$Multipath]
    }
    if ($Name) {
        $body.NAME = $Name
    }
    if ($HostName) {
        $hostObject = @(Get-DMhosts -WebSession $session | Where-Object Name -EQ $HostName)[0]
        $body.PARENTTYPE = 21
        $body.PARENTID = $hostObject.Id
    }
    if ($UseChap) {
        $body.CHAPNAME = $ChapName
        $body.CHAPPASSWORD = $ChapPassword
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

    $response = Invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'iscsi_initiator' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanstorHostinitiatorISCSI]::new($response.data, $session)
    }
    return $response.error
}
