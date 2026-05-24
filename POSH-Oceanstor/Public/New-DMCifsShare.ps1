function New-DMCifsShare {
    <#
    .SYNOPSIS
        Creates a Huawei OceanStor CIFS share.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$WebSession,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateLength(1, 80)]
        [ValidateScript({
                if ($_ -match '[/\\\[\]:|<>+;,?*=]') {
                    throw 'ShareName contains a character not permitted by the CIFS share interface.'
                }
                if ($_ -match '^\s|\s$' -or $_ -match '^(?i:ipc\$|autohome|~|print\$)$') {
                    throw 'ShareName is reserved or begins/ends with a space.'
                }
                return $true
            })]
        [string]$ShareName,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
                $session = if ($WebSession) {
                    $WebSession
                }
                else {
                    $deviceManager
                }
                $fileSystems = @(get-DMFileSystem -WebSession $session)
                $matchingItems = @($fileSystems | Where-Object Name -EQ $_)
                if ($matchingItems.Count -eq 1) {
                    return $true
                }
                if ($matchingItems.Count -gt 1) {
                    throw "FileSystemName is ambiguous because more than one file system is named '$_'."
                }
                throw "Invalid FileSystemName. Valid values are: $($fileSystems.Name -join ', ')"
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $session = if ($fakeBoundParameters.ContainsKey('WebSession')) {
                    $fakeBoundParameters.WebSession
                }
                else {
                    $deviceManager
                }
                (get-DMFileSystem -WebSession $session).Name | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" }
            })]
        [string]$FileSystemName,

        [Parameter(Position = 3)]
        [ValidateLength(2, 1024)]
        [string]$SharePath,

        [Parameter(Position = 4)]
        [ValidateLength(0, 255)]
        [string]$Description,

        [ValidateSet('Normal', 'HomeDir', 'All')]
        [string]$SubType = 'Normal',

        [ValidateSet('None', 'Manual', 'Documents', 'Programs')]
        [string]$OfflineFileMode = 'Manual',

        [bool]$EnableOplock = $true,

        [bool]$EnableNotify = $true,

        [bool]$EnableContinuousAvailability = $false,

        [bool]$EnablePreviousVersions = $true,

        [bool]$EnableSnapshotVisible = $true,

        [bool]$EnableSmb3Encryption = $false,

        [bool]$AllowUnencryptedAccess = $false,

        [string]$VstoreId,

        [string]$DTreeId
    )

    $session = if ($WebSession) {
        $WebSession
    }
    else {
        $deviceManager
    }
    $fileSystem = @(get-DMFileSystem -WebSession $session | Where-Object Name -EQ $FileSystemName)[0]
    $subTypeValue = @{ Normal = 0; HomeDir = 1; All = 2 }[$SubType]
    $offlineFileModeValue = @{ None = 0; Manual = 1; Documents = 2; Programs = 3 }[$OfflineFileMode]
    $body = @{
        NAME                       = $ShareName
        SHAREPATH                  = if ($SharePath) {
            $SharePath
        }
        else {
            "/$FileSystemName/"
        }
        FSID                       = $fileSystem.Id
        subType                    = $subTypeValue
        OFFLINEFILEMODE            = $offlineFileModeValue
        ENABLEOPLOCK               = $EnableOplock
        ENABLENOTIFY               = $EnableNotify
        ENABLECA                   = $EnableContinuousAvailability
        ENABLESHOWPREVIOUSVERSIONS = $EnablePreviousVersions
        ENABLESHOWSNAPSHOT         = $EnableSnapshotVisible
        smb3EncryptionEnable       = $EnableSmb3Encryption
        unencryptedAccess          = $AllowUnencryptedAccess
    }
    if ($Description) {
        $body.DESCRIPTION = $Description
    }
    if ($VstoreId) {
        $body.vstoreId = $VstoreId
    }
    if ($DTreeId) {
        $body.DTREEID = $DTreeId
    }

    $response = invoke-DeviceManager -WebSession $session -Method 'POST' -Resource 'CIFSSHARE' -BodyData $body
    if ($response.error.Code -eq 0) {
        return [OceanStorCIFSShare]::new($response.data, $session)
    }

    return $response.error
}
